"""
Finly database tests on a throw-away local Postgres (no Docker needed).

    pip install pgserver "psycopg[binary]"
    python sql/tests/run_db_tests.py

Applies 00..09, 11, 12 and 14 (+ the Supabase mock; 10 and 13 need pg_cron, which
only Supabase has) and checks the business rules: tax-id validation, RLS isolation,
derived balances, monthly flow, transfers, credit card invoices/installments,
recurring generation, edit and delete, audit log and account deletion.
"""
import pathlib, sys, tempfile, uuid
import pgserver, psycopg

SQL = pathlib.Path(__file__).resolve().parent.parent
FILES = ["tests/00_mock_supabase.sql", "00_types.sql", "01_helpers.sql",
         "02_tables.sql", "03_logic.sql", "04_security.sql", "07_hardening.sql", "08_credit_card.sql", "09_budget_end_marker.sql",
         "11_monthly_flow.sql", "12_recurring_edit_delete.sql", "14_restore_transfer.sql"]

passed = failed = 0
def check(name, cond, extra=""):
    global passed, failed
    if cond: passed += 1; print(f"  ok   {name}")
    else:    failed += 1; print(f"  FAIL {name} {extra}")

def raises(conn, sql, params=None, contains=None):
    """True if the statement fails (rolled back in a savepoint)."""
    try:
        with conn.transaction():
            conn.execute(sql, params)
        return False
    except psycopg.Error as e:
        return contains is None or contains.lower() in str(e).lower()

def as_user(conn, uid):
    conn.execute("reset role")
    conn.execute("select set_config('request.jwt.claim.sub', %s, false)", (str(uid) if uid else "",))
    conn.execute("set role authenticated")

def one(conn, sql, params=None):
    return conn.execute(sql, params).fetchone()[0]

def main():
    tmp = tempfile.mkdtemp()
    srv = pgserver.get_server(tmp, cleanup_mode="stop")
    conn = psycopg.connect(srv.get_uri(), autocommit=True)
    for f in FILES:
        try:
            conn.execute((SQL / f).read_text(encoding="utf-8"))
        except psycopg.Error as e:
            print(f"APPLY FAILED in {f}: {e}"); sys.exit(1)
    print("schema applied\n")

    # ---- validators --------------------------------------------------------
    print("validators")
    v = lambda fn, x: one(conn, f"select public.{fn}(%s)", (x,))
    check("valid CPF", v("is_valid_cpf", "52998224725"))
    check("invalid CPF checksum", not v("is_valid_cpf", "52998224726"))
    check("repeated-digit CPF", not v("is_valid_cpf", "11111111111"))
    check("valid numeric CNPJ", v("is_valid_cnpj", "11222333000181"))
    check("invalid numeric CNPJ", not v("is_valid_cnpj", "11222333000182"))
    check("alphanumeric CNPJ (first issued by RFB)", v("is_valid_cnpj", "00000000E08G12"))
    check("alphanumeric CNPJ wrong DV", not v("is_valid_cnpj", "00000000E08G13"))

    # ---- users & workspaces ---------------------------------------------
    print("workspaces")
    A, B = uuid.uuid4(), uuid.uuid4()
    for u, n in ((A, "Ana"), (B, "Bruno")):
        conn.execute("insert into auth.users(id,email,raw_user_meta_data) values (%s,%s,%s::jsonb)",
                     (u, f"{n}@x.com", f'{{"full_name":"{n} Teste"}}'))
    check("profile + settings auto-created", one(conn, "select count(*) from public.profiles") == 2
          and one(conn, "select count(*) from public.user_settings") == 2)

    as_user(conn, A)
    check("bad CPF rejected", raises(conn, "select public.create_workspace('Pessoal','personal','111.111.111-11')", contains="invalid_tax_id"))
    ws_p = one(conn, "select (public.create_workspace('Pessoal','personal','529.982.247-25')).id")
    ws_b = one(conn, "select (public.create_workspace('Minha Empresa','business','11.222.333/0001-81')).id")
    check("2nd personal workspace rejected", raises(conn, "select public.create_workspace('Outro','personal','529.982.247-25')", contains="already_exists"))
    check("active workspace set to the first one", str(one(conn, "select active_workspace_id from public.profiles")) == str(ws_p))
    check("categories seeded", one(conn, "select count(*) from public.categories where workspace_id=%s", (ws_p,)) == 13)
    check("direct workspace INSERT blocked", raises(conn, "insert into public.workspaces(owner_id,name,type,tax_id_type,tax_id) values (%s,'x','personal','cpf','52998224725')", (A,)))
    check("tax id / type immutable", raises(conn, "update public.workspaces set tax_id='11222333000181' where id=%s", (ws_p,)) )
    one(conn, "select public.switch_workspace(%s)", (ws_b,)) if False else conn.execute("select public.switch_workspace(%s)", (ws_b,))
    check("switch_workspace updates active", str(one(conn, "select active_workspace_id from public.profiles")) == str(ws_b))

    # ---- accounts, transactions, balances ---------------------------------
    print("accounts / transactions / balances")
    chk = one(conn, "insert into public.accounts(workspace_id,name,type,opening_balance_cents) values (%s,'Nubank','checking',100000) returning id", (ws_p,))
    sav = one(conn, "insert into public.accounts(workspace_id,name,type) values (%s,'Poupanca','savings') returning id", (ws_p,))
    biz = one(conn, "insert into public.accounts(workspace_id,name,type,opening_balance_cents) values (%s,'Conta PJ','checking',500000) returning id", (ws_b,))
    cat_food = one(conn, "select id from public.categories where workspace_id=%s and name='Alimentação'", (ws_p,))
    cat_sal  = one(conn, "select id from public.categories where workspace_id=%s and name='Salário'", (ws_p,))

    ins = ("insert into public.transactions(workspace_id,account_id,currency,category_id,type,status,amount_cents,description,occurred_at) "
           "values (%s,%s,'BRL',%s,%s,%s,%s,%s,now()) returning id")
    t1 = one(conn, ins, (ws_p, chk, cat_food, 'expense', 'posted', 25000, 'Mercado'))
    one(conn, ins, (ws_p, chk, cat_sal, 'income', 'posted', 300000, 'Salario'))
    one(conn, ins, (ws_p, chk, cat_food, 'expense', 'pending', 8000, 'Pizza'))
    one(conn, ins, (ws_p, chk, cat_food, 'expense', 'failed', 99999, 'Falhou'))
    bal = conn.execute("select posted_balance_cents, projected_balance_cents from public.account_balances where account_id=%s", (chk,)).fetchone()
    check("posted balance = 100000+300000-25000", bal[0] == 375000, bal)
    check("projected includes pending, ignores failed", bal[1] == 367000, bal)
    check("expense with income category rejected", raises(conn, ins, (ws_p, chk, cat_sal, 'expense', 'posted', 100, 'x'), contains="category kind"))
    check("negative amount rejected", raises(conn, ins, (ws_p, chk, cat_food, 'expense', 'posted', -5, 'x')))
    check("direct transfer leg insert blocked by RLS", raises(conn, ins, (ws_p, chk, None, 'transfer_out', 'posted', 100, 'x')))
    conn.execute("update public.transactions set deleted_at=now() where id=%s", (t1,))
    t2 = one(conn, ins, (ws_p, chk, cat_food, 'expense', 'posted', 100, 'Status test'))
    check("posted -> failed rejected, posted -> pending allowed",
          raises(conn, "update public.transactions set status='failed' where id=%s", (t2,), contains="invalid status")
          and not raises(conn, "update public.transactions set status='pending' where id=%s", (t2,)))
    conn.execute("update public.transactions set status='posted' where id=%s", (t2,))
    conn.execute("update public.transactions set deleted_at=now() where id=%s", (t2,))
    check("soft-deleted transaction leaves balance", one(conn, "select posted_balance_cents from public.account_balances where account_id=%s", (chk,)) == 400000)

    # ---- monthly flow view ------------------------------------------------
    print("monthly flow")
    this_month = "date_trunc('month', now() at time zone 'America/Sao_Paulo')::date"
    flow = lambda: conn.execute(f"select income_cents, expense_cents from public.monthly_flow where workspace_id=%s and currency='BRL' and month={this_month}", (ws_p,)).fetchone()
    check("monthly_flow counts only posted income and expenses (not pending, failed or deleted)", flow() == (300000, 0), flow())
    one(conn, ins, (ws_p, chk, cat_food, 'expense', 'posted', 4500, 'Lanche'))
    check("a new posted expense shows up in monthly_flow", flow() == (300000, 4500), flow())

    # ---- RLS isolation ---------------------------------------------------
    print("isolation")
    as_user(conn, B)
    check("user B sees no workspaces", one(conn, "select count(*) from public.workspaces") == 0)
    check("user B sees no transactions", one(conn, "select count(*) from public.transactions") == 0)
    check("user B sees no balances", one(conn, "select count(*) from public.account_balances") == 0)
    check("user B sees no monthly_flow", one(conn, "select count(*) from public.monthly_flow") == 0)
    check("user B cannot insert into A's workspace", raises(conn, ins, (ws_p, chk, cat_food, 'expense', 'posted', 100, 'hack')))
    check("user B cannot switch to A's workspace", raises(conn, "select public.switch_workspace(%s)", (ws_p,), contains="forbidden"))
    check("user B cannot transfer from A's account", raises(conn, "select public.create_transfer(%s,%s,100,'x')", (chk, sav), contains="forbidden"))
    as_user(conn, None)
    check("anonymous call to RPC fails", raises(conn, "select public.create_workspace('x','personal','52998224725')"))
    as_user(conn, A)

    # ---- transfers --------------------------------------------------------
    print("transfers")
    tr = one(conn, "select public.create_transfer(%s,%s,50000,'Reserva')", (chk, sav))
    check("two legs created", one(conn, "select count(*) from public.transactions where transfer_id=%s", (tr,)) == 2)
    check("leg amounts move balances", one(conn, "select posted_balance_cents from public.account_balances where account_id=%s", (sav,)) == 50000)
    check("internal transfer across workspaces rejected", raises(conn, "select public.create_transfer(%s,%s,100,'x')", (biz, chk), contains="inside one workspace"))
    ow = one(conn, "select public.create_transfer(%s,%s,200000,'Pro-labore',now(),'owner_withdrawal')", (biz, chk))
    check("owner withdrawal business->personal", one(conn, "select count(*) from public.transactions where transfer_id=%s", (ow,)) == 2)
    check("owner withdrawal wrong direction rejected", raises(conn, "select public.create_transfer(%s,%s,100,'x',now(),'owner_withdrawal')", (chk, biz)))
    leg = one(conn, "select id from public.transactions where transfer_id=%s and type='transfer_out'", (tr,))
    check("single leg cannot be edited directly", raises(conn, "update public.transactions set amount_cents=1 where id=%s", (leg,), contains="managed"))
    conn.execute("select public.delete_transfer(%s)", (tr,))
    check("delete_transfer soft-deletes both legs", one(conn, "select count(*) from public.transactions where transfer_id=%s and deleted_at is not null", (tr,)) == 2)
    check("balance restored after delete_transfer", one(conn, "select posted_balance_cents from public.account_balances where account_id=%s", (sav,)) == 0)
    check("transfer legs do not count in monthly_flow", flow() == (300000, 4500), flow())

    # ---- restore transfer -------------------------------------------------
    print("restore transfer")
    conn.execute("select public.restore_transfer(%s)", (tr,))
    check("restore_transfer brings both legs back", one(conn, "select count(*) from public.transactions where transfer_id=%s and deleted_at is null", (tr,)) == 2)
    check("the restored transfer moves the balances again", one(conn, "select posted_balance_cents from public.account_balances where account_id=%s", (sav,)) == 50000)
    check("restoring a transfer that is not deleted is refused", raises(conn, "select public.restore_transfer(%s)", (tr,), contains="not deleted"))
    as_user(conn, B)
    check("another user cannot restore A's transfer", raises(conn, "select public.restore_transfer(%s)", (tr,), contains="forbidden"))
    as_user(conn, A)
    conn.execute("select public.delete_transfer(%s)", (tr,))

    # ---- credit card ------------------------------------------------------
    print("credit card")
    card = one(conn, "insert into public.accounts(workspace_id,name,type) values (%s,'Cartao','credit_card') returning id", (ws_p,))
    check("card needs details row for charges", raises(conn, ins, (ws_p, card, cat_food, 'expense', 'posted', 1000, 'x'), contains="not a credit card"))
    conn.execute("insert into public.credit_card_details(account_id,limit_cents,closing_day,due_day) values (%s,500000,10,17)", (card,))
    check("non-card account cannot have details", raises(conn, "insert into public.credit_card_details(account_id,limit_cents,closing_day,due_day) values (%s,1,1,1)", (chk,)))
    d_before = "2026-03-05 12:00-03"; d_after = "2026-03-20 12:00-03"
    q = ("insert into public.transactions(workspace_id,account_id,currency,category_id,type,status,amount_cents,description,occurred_at) "
         "values (%s,%s,'BRL',%s,'expense','posted',%s,%s,%s) returning invoice_id")
    i1 = one(conn, q, (ws_p, card, cat_food, 10000, 'Antes do fechamento', d_before))
    i2 = one(conn, q, (ws_p, card, cat_food, 20000, 'Depois do fechamento', d_after))
    r1 = conn.execute("select reference_month, period_start, period_end, due_date from public.credit_card_invoices where id=%s", (i1,)).fetchone()
    r2 = conn.execute("select reference_month, period_start, period_end, due_date from public.credit_card_invoices where id=%s", (i2,)).fetchone()
    check("purchase before closing -> March invoice (due 17/03)", str(r1) == "(datetime.date(2026, 3, 1), datetime.date(2026, 2, 11), datetime.date(2026, 3, 10), datetime.date(2026, 3, 17))", r1)
    check("purchase after closing -> April invoice", str(r2[0]) == "2026-04-01" and i1 != i2, r2)
    check("invoice total derived", one(conn, "select total_cents from public.invoice_totals where invoice_id=%s", (i1,)) == 10000)
    grp = one(conn, "select public.create_installments(%s,%s,100001,3,'TV',%s)", (card, cat_food, d_before))
    rows = conn.execute("select t.installment_number, t.amount_cents, t.status, i.reference_month from public.transactions t join public.credit_card_invoices i on i.id=t.invoice_id where installment_group_id=%s order by 1", (grp,)).fetchall()
    check("installments: remainder on 1st, sum preserved", [r[1] for r in rows] == [33335, 33333, 33333] and sum(r[1] for r in rows) == 100001, rows)
    check("installments: consecutive invoices, 1st posted rest pending",
          [str(r[3]) for r in rows] == ["2026-03-01", "2026-04-01", "2026-05-01"] and [r[2] for r in rows] == ["posted", "pending", "pending"], rows)
    cb = conn.execute("select posted_balance_cents, projected_balance_cents from public.account_balances where account_id=%s", (card,)).fetchone()
    check("card balance is negative debt; limit used = -projected (installments count)", cb == (-63335, -130001), cb)
    pay = one(conn, "select public.pay_invoice(%s,%s)", (i1, chk))
    inv = conn.execute("select status, paid_at is not null from public.credit_card_invoices where id=%s", (i1,)).fetchone()
    check("pay_invoice marks paid", inv == ("paid", True), inv)
    mar_tx = one(conn, "select id from public.transactions where invoice_id=%s and installment_number is null limit 1", (i1,))
    check("paid invoice locks its transactions", raises(conn, "update public.transactions set amount_cents=1 where id=%s", (mar_tx,), contains="paid"))
    check("paying twice rejected", raises(conn, "select public.pay_invoice(%s,%s)", (i1, chk), contains="already paid"))
    conn.execute("select public.delete_transfer(%s)", (pay,))
    check("deleting payment reopens invoice", one(conn, "select status from public.credit_card_invoices where id=%s", (i1,)) in ("open", "closed"))
    check("a card payment cannot be restored (the invoice has to be paid again)", raises(conn, "select public.restore_transfer(%s)", (pay,), contains="card payment"))

    # ---- recurring --------------------------------------------------------
    print("recurring")
    rid = one(conn, "insert into public.recurring_transactions(workspace_id,account_id,currency,category_id,type,amount_cents,description,frequency,start_date) "
                    "values (%s,%s,'BRL',%s,'expense',12000,'Aluguel','monthly', current_date) returning id", (ws_p, chk, cat_food))
    n1 = one(conn, "select public.generate_my_recurring(current_date + 70)")
    n2 = one(conn, "select public.generate_my_recurring(current_date + 70)")
    check("recurring generates pending instances", n1 >= 2 and all(s == 'pending' for (s,) in conn.execute("select status from public.transactions where recurring_id=%s", (rid,)).fetchall()), n1)
    check("recurring generation is idempotent", n2 == 0, n2)

    # ---- recurring: edit and delete ---------------------------------------
    print("recurring edit and delete")
    conn.execute("select public.update_recurring(%s,'  Aluguel novo ',13000,%s,null)", (rid, cat_food))
    row = conn.execute("select description, amount_cents from public.recurring_transactions where id=%s", (rid,)).fetchone()
    check("update_recurring changes the template and trims the description", row == ("Aluguel novo", 13000), row)
    pend = conn.execute("select distinct description, amount_cents from public.transactions where recurring_id=%s and status='pending' and deleted_at is null", (rid,)).fetchall()
    check("pending occurrences from today on follow the new values", pend == [("Aluguel novo", 13000)], pend)
    conn.execute("select public.update_recurring(%s,'Aluguel novo',13000,%s,current_date + 5)", (rid, cat_food))
    live = one(conn, "select count(*) from public.transactions where recurring_id=%s and deleted_at is null", (rid,))
    check("an end date removes the pending occurrences after it", live == 1, live)
    check("a category of the other kind is refused", raises(conn, "select public.update_recurring(%s,'x',1000,%s,null)", (rid, cat_sal), contains="category kind"))
    check("a zero amount is refused", raises(conn, "select public.update_recurring(%s,'x',0,%s,null)", (rid, cat_food)))
    check("an end date before the start date is refused", raises(conn, "select public.update_recurring(%s,'x',1000,%s,current_date - 400)", (rid, cat_food)))
    as_user(conn, B)
    check("another user cannot edit or delete A's recurring item",
          raises(conn, "select public.update_recurring(%s,'x',1000,null,null)", (rid,), contains="forbidden")
          and raises(conn, "select public.delete_recurring(%s)", (rid,), contains="forbidden"))
    as_user(conn, None)
    check("anonymous cannot call the recurring functions", raises(conn, "select public.delete_recurring(%s)", (rid,)))
    as_user(conn, A)
    rid2 = one(conn, "insert into public.recurring_transactions(workspace_id,account_id,currency,category_id,type,amount_cents,description,frequency,start_date) "
                     "values (%s,%s,'BRL',%s,'expense',15000,'Faxina','weekly', current_date) returning id", (ws_p, chk, cat_food))
    conn.execute("select public.generate_my_recurring(current_date + 20)")
    ids2 = [r[0] for r in conn.execute("select id from public.transactions where recurring_id=%s order by scheduled_for", (rid2,)).fetchall()]
    conn.execute("update public.transactions set status='posted' where id=%s", (ids2[0],))
    conn.execute("select public.delete_recurring(%s)", (rid2,))
    check("delete_recurring removes the item", one(conn, "select count(*) from public.recurring_transactions where id=%s", (rid2,)) == 0)
    rows2 = conn.execute("select deleted_at is not null, recurring_id is null, scheduled_for is null, status::text from public.transactions where id = any(%s) order by occurred_at", (ids2,)).fetchall()
    check("a confirmed occurrence stays in the history, detached from the item",
          len(ids2) >= 3 and rows2[0] == (False, True, True, "posted"), rows2)
    check("pending occurrences are removed and detached",
          all(r == (True, True, True, "pending") for r in rows2[1:]), rows2)

    # ---- trash purge ------------------------------------------------------
    print("trash purge")
    old = one(conn, ins, (ws_p, chk, cat_food, 'expense', 'posted', 100, 'Velha'))
    recent = one(conn, ins, (ws_p, chk, cat_food, 'expense', 'posted', 100, 'Recente'))
    conn.execute("update public.transactions set deleted_at = now() - interval '40 days' where id=%s", (old,))
    conn.execute("update public.transactions set deleted_at = now() - interval '5 days' where id=%s", (recent,))
    check("a soft-deleted transaction is still visible to its owner (the trash screen reads it)",
          one(conn, "select count(*) from public.transactions where id=%s and deleted_at is not null", (recent,)) == 1)
    conn.execute("reset role")
    purged = one(conn, "select private.purge_deleted()")
    as_user(conn, A)
    check("purge_deleted removes only what was deleted more than 30 days ago",
          purged >= 1
          and one(conn, "select count(*) from public.transactions where id=%s", (old,)) == 0
          and one(conn, "select count(*) from public.transactions where id=%s", (recent,)) == 1, purged)

    # ---- budgets & views --------------------------------------------------
    print("budgets")
    check("budget only for expense categories", raises(conn, "insert into public.budgets(workspace_id,category_id,effective_from,limit_cents) values (%s,%s,date_trunc('month',now())::date,100000)", (ws_p, cat_sal)))
    conn.execute("insert into public.budgets(workspace_id,category_id,effective_from,limit_cents) values (%s,%s,date_trunc('month',now())::date,100000)", (ws_p, cat_food))
    next_month = "date_trunc('month', now() + interval '1 month')::date"
    conn.execute(f"insert into public.budgets(workspace_id,category_id,effective_from,limit_cents) values (%s,%s,{next_month},0)", (ws_p, cat_food))
    check("a budget with limit 0 is allowed (end marker)", one(conn, "select count(*) from public.budgets where limit_cents = 0") == 1)
    check("a negative budget limit is still rejected", raises(conn, f"insert into public.budgets(workspace_id,category_id,effective_from,limit_cents) values (%s,%s,{next_month} + interval '1 month',-1)", (ws_p, cat_food)))
    check("monthly_category_spend view works", one(conn, "select count(*) from public.monthly_category_spend where workspace_id=%s", (ws_p,)) >= 1)

    # ---- audit ------------------------------------------------------------
    print("audit")
    check("audit rows written by triggers", one(conn, "select count(*) from public.audit_logs") > 10)
    check("audit row records the acting user", one(conn, "select count(*) from public.audit_logs where changed_by=%s", (A,)) > 0)
    check("audit is read-only for the API", raises(conn, "delete from public.audit_logs") and raises(conn, "insert into public.audit_logs(owner_id,table_name,record_id,action) values (%s,'x',gen_random_uuid(),'INSERT')", (A,)))
    as_user(conn, B)
    check("user B cannot read A's audit log", one(conn, "select count(*) from public.audit_logs") == 0)
    conn.execute("reset role")
    check("append-only guard blocks even superuser UPDATE", raises(conn, "update public.audit_logs set action='DELETE'", contains="append-only"))

    # ---- credit card creation ---------------------------------------------
    print("credit card creation")
    as_user(conn, A)
    card2 = one(conn, "select public.create_credit_card(%s,'Cartao 2','BRL',300000,5,12)", (ws_p,))
    row = conn.execute("select a.type::text, a.opening_balance_cents, d.limit_cents, d.closing_day, d.due_day from public.accounts a join public.credit_card_details d on d.account_id=a.id where a.id=%s", (card2,)).fetchone()
    check("create_credit_card creates the account and its settings together", row == ("credit_card", 0, 300000, 5, 12), row)
    check("an invalid closing day leaves no orphan card account",
          raises(conn, "select public.create_credit_card(%s,'Cartao 3','BRL',1000,40,12)", (ws_p,))
          and one(conn, "select count(*) from public.accounts where name='Cartao 3'") == 0)
    as_user(conn, B)
    check("another user cannot create a card in A's workspace",
          raises(conn, "select public.create_credit_card(%s,'Hack','BRL',1000,5,12)", (ws_p,), contains="forbidden"))
    as_user(conn, None)
    check("anonymous cannot call create_credit_card", raises(conn, "select public.create_credit_card(%s,'Hack','BRL',1000,5,12)", (ws_p,)))
    as_user(conn, A)

    # ---- tax category / config ----------------------------------------------
    print("misc")
    check("business 'Impostos' category flagged is_tax", one(conn, "select count(*) from public.categories where workspace_id=%s and is_tax", (ws_b,)) == 1)
    conn.execute("reset role"); conn.execute("set role anon")
    check("anon can read app_config (force update) but not data", one(conn, "select count(*) from public.app_config") == 1 and raises(conn, "select count(*) from public.profiles"))
    check("anon cannot read monthly_flow", raises(conn, "select count(*) from public.monthly_flow"))
    as_user(conn, A)

    # ---- account deletion -------------------------------------------------
    print("account deletion")
    as_user(conn, A)
    conn.execute("select public.delete_my_account()")
    conn.execute("reset role")
    left = [one(conn, f"select count(*) from public.{t}") for t in ("transactions", "accounts", "workspaces", "transfers", "audit_logs", "categories", "profiles")]
    check("everything of user A erased (incl. audit); user B untouched", left == [0, 0, 0, 0, 0, 0, 1], left)

    print(f"\n{passed} passed, {failed} failed")
    sys.exit(1 if failed else 0)

if __name__ == "__main__":
    main()