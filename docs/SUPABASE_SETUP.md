# Finly - Supabase setup (configured by hand)

Everything in `sql/` is applied from files. The settings below live in the Supabase **dashboard**, so no file in git captures them. If you ever recreate the project, redo this list after applying `sql/00` to `sql/16`.

Project: `Finly`, region sa-east-1.

## 1. Authentication > Sign In / Providers > Email

| Setting | Value | Why |
|---|---|---|
| Enable email provider | on | e-mail + password sign-in |
| Confirm email | on | sign-up needs a verified e-mail (the app shows the verification screen) |
| Secure email change | on | an e-mail change must be confirmed on both addresses (the screen for it is not built yet) |
| Secure password change | off | the app asks for the current password itself before changing it |
| Require current password when updating | off | same reason |
| Minimum password length | 8 (recommended) | matches the app, enforced even if someone bypasses the app |
| Password requirements | letters and digits (recommended) | matches the app's rule |
| Prevent use of leaked passwords | off | needs the Pro plan |
| Email OTP expiration | 3600 seconds | how long a recovery code is valid |
| Email OTP length | **8** | the recovery code has 8 digits; the app accepts 6 to 10 |

## 2. Authentication > Emails > Reset Password template

The forgot-password flow shows a **code**, so the template must print it. Subject:

```
Seu código para redefinir a senha do Finly
```

Message body (HTML):

```html
<h2>Redefinir senha</h2>
<p>Use este código no app Finly para criar uma nova senha:</p>
<p style="font-size:28px;font-weight:bold;letter-spacing:4px;">{{ .Token }}</p>
<p>O código vale por pouco tempo. Se você não pediu, ignore este e-mail.</p>
```

Leave the **Confirm signup** template as it is: sign-up still uses the link.

## 3. Authentication > Emails > SMTP Settings

- By default Supabase sends auth e-mails with a built-in sender meant for testing: **2 e-mails per hour for the whole project**, counting sign-up confirmations and recovery codes together.
- Before real users: enable **custom SMTP** with a transactional e-mail service. These services need a **domain you own** (DNS records for SPF/DKIM); a free address such as Gmail cannot be authenticated. With custom SMTP the default limit becomes 30 e-mails per hour, adjustable under Authentication > Rate Limits.
- Status: not configured yet (tracked in `POLISH.md`).

## 4. Database > Extensions

- `pg_cron`: enabled by `sql/10_schedule_jobs.sql`. Jobs `finly-close-invoices` (03:05 UTC) and `finly-generate-recurring` (03:15 UTC); `sql/13_schedule_purge.sql` adds `finly-purge-deleted` (03:25 UTC), which removes soft-deleted rows after 30 days.
- Check that they ran: `select * from cron.job_run_details order by start_time desc limit 10;`

## 5. Notifications need nothing here

The reminders are local notifications scheduled by the app on the phone, so there is no Firebase project, no Edge Function and no key to configure. (Push notifications for budget alerts would need a server and are *(planned)*.) On the phone: allow notifications; on Xiaomi/HyperOS also turn **Autostart** on and set the battery to **No restrictions** for Finly, or the system may swallow the reminders.

## 6. Things that must never be in the app

The `service_role` key. Only the project URL and the anon key go in `env.json`, which is git-ignored.
