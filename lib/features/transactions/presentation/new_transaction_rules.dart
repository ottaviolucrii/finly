import 'package:finly/features/categories/domain/entities/category_entity.dart';

/// The day options of the new transaction sheet.
enum QuickDay { today, yesterday, other }

DateTime _day(DateTime date) => DateTime(date.year, date.month, date.day);

/// True when [date] is a day after the day of [now].
bool isFutureDay(DateTime date, DateTime now) => _day(date).isAfter(_day(now));

/// When the transaction is recorded: today keeps the time of [now]; any other
/// day is recorded at noon (so time zones never move it to another day).
DateTime occurredAtFor(DateTime date, DateTime now) {
  return _day(date) == _day(now) ? now : DateTime(date.year, date.month, date.day, 12);
}

/// The day a [QuickDay] stands for ([picked] is the day of "Outra data").
DateTime dayFor(QuickDay quick, DateTime now, DateTime picked) => switch (quick) {
      QuickDay.today => _day(now),
      QuickDay.yesterday => _day(now).subtract(const Duration(days: 1)),
      QuickDay.other => _day(picked),
    };

/// The description to save: what was typed, or the name of the category when
/// nothing was typed. Null when there is neither (the form asks for one).
String? descriptionFor(String typed, CategoryEntity? category) {
  final text = typed.trim();
  if (text.isNotEmpty) return text;
  return category?.name;
}

/// The longest description the database accepts.
const maxDescriptionLength = 200;
