import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../models/currency.dart';
import '../models/subscription.dart';
import '../state/subs_provider.dart' show MonthMood;

const supportedLocales = [Locale('en'), Locale('ru')];

/// Every user-visible string and locale-aware formatter.
///
/// Strings live next to each other as `_t('English', 'Русский')` pairs, so a
/// missing translation is impossible and both languages are reviewed together.
/// Get it with `S.of(context)`.
class S {
  S(Locale locale) : code = locale.languageCode == 'ru' ? 'ru' : 'en';

  final String code;
  bool get _ru => code == 'ru';

  static S of(BuildContext context) => Localizations.of<S>(context, S)!;

  static const LocalizationsDelegate<S> delegate = _Delegate();

  String _t(String en, String ru) => _ru ? ru : en;

  String _plural(
    int n, {
    required String one,
    required String few,
    required String many,
    required String other,
  }) => Intl.plural(
    n,
    one: one,
    few: few,
    many: many,
    other: other,
    locale: code,
  );

  // ── Formatting ─────────────────────────────────────────────────────────

  String get _numLocale => _ru ? 'ru' : 'en_US';

  /// `1 234,56 ₽` / `$1,234.56`
  String money(double value, String currency, {bool whole = false}) {
    final c = Currency.of(currency);
    return NumberFormat.currency(
      locale: _numLocale,
      symbol: c.symbol,
      decimalDigits: whole ? 0 : c.decimals,
    ).format(value);
  }

  /// Short form for tiny calendar cells: `$11`, `3,5K ₽`.
  String moneyTiny(double value, String currency) {
    final c = Currency.of(currency);
    final String number;
    if (value >= 1000) {
      number = '${NumberFormat('#,##0.#', _numLocale).format(value / 1000)}K';
    } else {
      number = NumberFormat('#,##0', _numLocale).format(value.round());
    }
    return _ru ? '$number ${c.symbol}' : '${c.symbol}$number';
  }

  /// Parses user input with either `,` or `.` as decimal separator
  /// and spaces as thousands separators.
  static double? parseAmount(String text) {
    final t = text.replaceAll(RegExp(r'[\s ]'), '').replaceAll(',', '.');
    if (t.isEmpty) return null;
    final v = double.tryParse(t);
    return (v == null || v.isNaN || v.isInfinite) ? null : v;
  }

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  String monthYear(DateTime d) => _cap(DateFormat('LLLL yyyy', code).format(d));
  String monthShort(DateTime d) =>
      _cap(DateFormat('LLL', code).format(d).replaceAll('.', ''));
  String dayMonth(DateTime d) => DateFormat('d MMM', code).format(d);
  String dayMonthYear(DateTime d) => DateFormat('d MMM yyyy', code).format(d);
  String longDate(DateTime d) => DateFormat('d MMMM yyyy', code).format(d);
  String weekdayDate(DateTime d) =>
      _cap(DateFormat('EEEE, d MMMM', code).format(d));
  String dateTime(DateTime d) =>
      DateFormat('d MMM yyyy, HH:mm', code).format(d);

  /// Monday-first short weekday names.
  List<String> get weekdays => [
    for (var i = 0; i < 7; i++)
      _cap(DateFormat('E', code).format(DateTime(2024, 1, 1 + i))),
  ];

  /// "Today", "Tomorrow", "in 3 days", "12 Oct" (for dates ≥ a week away).
  String relativeDay(DateTime date, DateTime today) {
    final diff = DateTime.utc(
      date.year,
      date.month,
      date.day,
    ).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
    if (diff == 0) return _t('Today', 'Сегодня');
    if (diff == 1) return _t('Tomorrow', 'Завтра');
    if (diff > 1 && diff < 7) return inDays(diff);
    if (date.year != today.year) return dayMonthYear(date);
    return dayMonth(date);
  }

  /// "1 October 2026 · in 3 days" within a week, otherwise just the date
  /// (relativeDay would repeat the date).
  String fullDate(DateTime date, DateTime today) {
    final diff = DateTime.utc(
      date.year,
      date.month,
      date.day,
    ).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
    return diff >= 0 && diff < 7
        ? '${longDate(date)} · ${relativeDay(date, today).toLowerCase()}'
        : longDate(date);
  }

  String inDays(int n) => _ru
      ? 'Через ${_plural(n, one: '$n день', few: '$n дня', many: '$n дней', other: '$n дня')}'
      : 'In $n ${n == 1 ? 'day' : 'days'}';

  // ── Enum labels ────────────────────────────────────────────────────────

  String status(SubStatus s) => switch (s) {
    SubStatus.active => _t('Active', 'Активна'),
    SubStatus.trial => _t('Trial', 'Пробная'),
    SubStatus.canceled => _t('Canceled', 'Отменена'),
    SubStatus.archived => _t('Archived', 'В архиве'),
  };

  /// Plural form for the list filter chips.
  String statusFilter(SubStatus s) => switch (s) {
    SubStatus.active => _t('Active', 'Активные'),
    SubStatus.trial => _t('Trial', 'Пробные'),
    SubStatus.canceled => _t('Canceled', 'Отменённые'),
    SubStatus.archived => _t('Archived', 'Архив'),
  };

  String category(SubCategory c) => switch (c) {
    SubCategory.entertainment => _t('Entertainment', 'Развлечения'),
    SubCategory.lifestyle => _t('Lifestyle', 'Образ жизни'),
    SubCategory.utilities => _t('Utilities', 'Сервисы и связь'),
    SubCategory.productivity => _t('Productivity', 'Работа'),
    SubCategory.health => _t('Health', 'Здоровье'),
    SubCategory.education => _t('Education', 'Обучение'),
    SubCategory.finance => _t('Finance', 'Финансы'),
    SubCategory.shopping => _t('Shopping', 'Покупки'),
    SubCategory.other => _t('Other', 'Другое'),
  };

  /// Chip label for the cycle picker.
  String cycleName(BillingCycle c) => switch (c) {
    BillingCycle.weekly => _t('Weekly', 'Неделя'),
    BillingCycle.monthly => _t('Monthly', 'Месяц'),
    BillingCycle.yearly => _t('Yearly', 'Год'),
    BillingCycle.oneTime => _t('One-time', 'Разово'),
  };

  /// "Monthly", "Every 3 months", "One-time".
  String cycle(BillingCycle c, int n) {
    if (c == BillingCycle.oneTime) return _t('One-time', 'Разовый платёж');
    if (n <= 1) {
      return switch (c) {
        BillingCycle.weekly => _t('Weekly', 'Еженедельно'),
        BillingCycle.monthly => _t('Monthly', 'Ежемесячно'),
        _ => _t('Yearly', 'Ежегодно'),
      };
    }
    return '${_t('Every', _plural(n, one: 'Каждый', few: 'Каждые', many: 'Каждые', other: 'Каждые'))} ${unit(c, n)}';
  }

  /// "3 months", "2 weeks" — the unit after "every".
  String unit(BillingCycle c, int n) => switch (c) {
    BillingCycle.weekly =>
      _ru
          ? _plural(
              n,
              one: '$n неделю',
              few: '$n недели',
              many: '$n недель',
              other: '$n недели',
            )
          : '$n ${n == 1 ? 'week' : 'weeks'}',
    BillingCycle.yearly =>
      _ru
          ? _plural(
              n,
              one: '$n год',
              few: '$n года',
              many: '$n лет',
              other: '$n года',
            )
          : '$n ${n == 1 ? 'year' : 'years'}',
    _ =>
      _ru
          ? _plural(
              n,
              one: '$n месяц',
              few: '$n месяца',
              many: '$n месяцев',
              other: '$n месяца',
            )
          : '$n ${n == 1 ? 'month' : 'months'}',
  };

  String reminder(int? days) => switch (days) {
    null => _t('Off', 'Выкл.'),
    0 => _t('Same day', 'В день списания'),
    _ =>
      _ru
          ? 'За ${_plural(days, one: '$days день', few: '$days дня', many: '$days дней', other: '$days дня')}'
          : '$days ${days == 1 ? 'day' : 'days'} before',
  };

  String mood(MonthMood m) => switch (m) {
    MonthMood.quiet => _t('Quiet month', 'Тихий месяц'),
    MonthMood.light => _t('Lighter than usual', 'Легче обычного'),
    MonthMood.regular => _t('Regular month', 'Обычный месяц'),
    MonthMood.heavy => _t('Heavier than usual', 'Тяжелее обычного'),
  };

  String moodHint(String average) =>
      _t('Average for the year: $average', 'В среднем за год: $average');

  String get perMonthShort => _t('/mo', '/мес');

  // ── App shell ──────────────────────────────────────────────────────────

  String get appName => 'Ledgify';
  String get tabCalendar => _t('Calendar', 'Календарь');
  String get tabList => _t('Subscriptions', 'Подписки');
  String get tabStats => _t('Statistics', 'Статистика');
  String get add => _t('Add subscription', 'Добавить подписку');
  String get search => _t('Search', 'Поиск');
  String get settings => _t('Settings', 'Настройки');
  String get close => _t('Close', 'Закрыть');
  String get cancel => _t('Cancel', 'Отмена');
  String get save => _t('Save', 'Сохранить');
  String get undo => _t('Undo', 'Вернуть');
  String get edit => _t('Edit', 'Изменить');
  String get delete => _t('Delete', 'Удалить');
  String get archive => _t('Archive', 'В архив');
  String get unarchive => _t('Restore', 'Вернуть из архива');
  String get remove => _t('Remove', 'Убрать');

  // ── Calendar ───────────────────────────────────────────────────────────

  String get prevMonth => _t('Previous month', 'Предыдущий месяц');
  String get nextMonth => _t('Next month', 'Следующий месяц');
  String get backToToday => _t('Back to today', 'К текущему месяцу');
  String get comingUp => _t('Coming up', 'Скоро списание');
  String get monthPayments =>
      _t('Payments this month', 'Платежи в этом месяце');
  String get noMonthPayments =>
      _t('No charges this month', 'В этом месяце списаний нет');
  String budgetOf(String spent, String budget) =>
      _t('$spent of $budget budget', '$spent из бюджета $budget');
  String paymentsCount(int n) => _ru
      ? _plural(
          n,
          one: '$n платёж',
          few: '$n платежа',
          many: '$n платежей',
          other: '$n платежа',
        )
      : '$n ${n == 1 ? 'charge' : 'charges'}';

  // ── List ───────────────────────────────────────────────────────────────

  String get searchHint =>
      _t('Search by name, category or note', 'Название, категория или заметка');
  String get filterAll => _t('All', 'Все');
  String get sortBy => _t('Sort', 'Сортировка');
  String get sortNext => _t('Next charge', 'Ближайшее списание');
  String get sortAmount => _t('Monthly cost', 'Стоимость в месяц');
  String get sortName => _t('Name', 'Название');
  String get sortCategory => _t('Category', 'Категория');
  String subscriptions(int n) => _ru
      ? _plural(
          n,
          one: '$n подписка',
          few: '$n подписки',
          many: '$n подписок',
          other: '$n подписки',
        )
      : '$n ${n == 1 ? 'subscription' : 'subscriptions'}';
  String get nothingFound => _t('Nothing found', 'Ничего не найдено');
  String get nothingFoundBody => _t(
    'Try another search or filter.',
    'Попробуйте другой запрос или фильтр.',
  );
  String get resetFilters => _t('Reset filters', 'Сбросить фильтры');
  String get emptyTitle => _t('No subscriptions yet', 'Подписок пока нет');
  String get emptyBody => _t(
    'Add the first one — Ledgify will show when and how much you pay.',
    'Добавьте первую — Ledgify покажет, когда и сколько вы платите.',
  );
  String get tryDemo => _t('Try with demo data', 'Посмотреть на примере');
  String get noCharge => _t('No upcoming charge', 'Списаний не будет');

  // ── Detail ─────────────────────────────────────────────────────────────

  String get amount => _t('Amount', 'Сумма');
  String get inBase => _t('In base currency', 'В основной валюте');
  String get billing => _t('Billing', 'Периодичность');
  String get nextCharge => _t('Next charge', 'Следующее списание');
  String get payingSince => _t('Paying since', 'Платите с');
  String get totalSpent => _t('Spent so far', 'Потрачено всего');
  String get categoryLabel => _t('Category', 'Категория');
  String get reminderLabel => _t('Reminder', 'Напоминание');
  String get notesLabel => _t('Notes', 'Заметки');
  String trialUntil(String date) =>
      _t('Free until $date', 'Бесплатно до $date');
  String canceledOn(String date) => _t('Canceled on $date', 'Отменена $date');
  String get archivedHint =>
      _t('Archived — not counted anywhere', 'В архиве — нигде не учитывается');
  String get oneTimePaid => _t('Paid once', 'Оплачено разово');

  // ── Form ───────────────────────────────────────────────────────────────

  String get newSub => _t('New subscription', 'Новая подписка');
  String get editSub => _t('Edit subscription', 'Редактирование');
  String get popular => _t('Popular services', 'Популярные сервисы');
  String get icon => _t('Icon', 'Иконка');
  String get name => _t('Name', 'Название');
  String get currency => _t('Currency', 'Валюта');
  String get firstPayment => _t('First charge', 'Первое списание');
  String get trialEnds =>
      _t('Trial ends (first paid day)', 'Конец пробного периода');
  String get paymentDate => _t('Payment date', 'Дата платежа');
  String get endDate => _t('Canceled on', 'Дата отмены');
  String get statusLabel => _t('Status', 'Статус');
  String get colorLabel => _t('Look', 'Оформление');
  String get notesHint =>
      _t('Plan, account, how to cancel…', 'Тариф, аккаунт, как отменить…');
  String get nameRequired => _t('Enter a name', 'Введите название');
  String get amountInvalid =>
      _t('Enter an amount greater than 0', 'Введите сумму больше 0');
  String get iconHint => _t('Emoji or 1–2 letters', 'Эмодзи или 1–2 буквы');
  String get addButton => _t('Add', 'Добавить');
  String get discardTitle => _t('Discard changes?', 'Не сохранять изменения?');
  String get discard => _t('Discard', 'Не сохранять');

  // ── Statistics ─────────────────────────────────────────────────────────

  String get perMonth => _t('Per month', 'В месяц');
  String get perYear => _t('Per year', 'В год');
  String get activeCount => _t('Active', 'Активных');
  String get budget => _t('Monthly budget', 'Бюджет на месяц');
  String get budgetEmpty => _t(
    'Set a limit to see how much is left.',
    'Задайте лимит — будет видно, сколько осталось.',
  );
  String get setBudget => _t('Set budget', 'Задать бюджет');
  String get changeBudget => _t('Change', 'Изменить');
  String budgetLeft(String v) => _t('$v left', 'Осталось $v');
  String budgetOver(String v) => _t('Over by $v', 'Перерасход $v');
  String get thisMonth => _t('This month', 'В этом месяце');
  String get trends => _t('Spending by month', 'Расходы по месяцам');
  String monthsN(int n) => _t('$n mo', '$n мес');
  String get byCategory => _t('By category', 'По категориям');
  String get mostExpensive => _t('Most expensive', 'Самые дорогие');
  String get nextChargeTitle => _t('Next charge', 'Ближайшее списание');
  String get statsEmpty =>
      _t('No active subscriptions', 'Нет активных подписок');
  String get statsEmptyBody => _t(
    'Statistics appear once you add a subscription.',
    'Статистика появится, когда вы добавите подписку.',
  );
  String get forecastHint => _t(
    'Based on active and trial subscriptions',
    'По активным и пробным подпискам',
  );

  // ── Settings ───────────────────────────────────────────────────────────

  String get appearance => _t('Appearance', 'Оформление');
  String get theme => _t('Theme', 'Тема');
  String get themeSystem => _t('System', 'Системная');
  String get themeLight => _t('Light', 'Светлая');
  String get themeDark => _t('Dark', 'Тёмная');
  String get language => _t('Language', 'Язык');
  String get moneySection => _t('Money', 'Деньги');
  String get baseCurrency => _t('Base currency', 'Основная валюта');
  String get baseCurrencyHint =>
      _t('All totals are shown in it', 'В ней считаются все итоги');
  String get rates => _t('Exchange rates', 'Курсы валют');
  String get ratesBuiltIn =>
      _t('Approximate built-in rates', 'Встроенные примерные курсы');
  String ratesUpdated(String when) => _t('Updated $when', 'Обновлены $when');
  String get updateRates => _t('Update', 'Обновить');
  String get resetRates => _t('Reset', 'Сбросить');
  String get ratesOk => _t('Exchange rates updated', 'Курсы обновлены');
  String get ratesFail => _t(
    'Could not load rates. Check the connection.',
    'Не удалось загрузить курсы. Проверьте интернет.',
  );
  String get ratesPrivacy => _t(
    'Only the rate table is downloaded from open.er-api.com — nothing about you is sent.',
    'С open.er-api.com скачивается только таблица курсов — о вас ничего не отправляется.',
  );
  String get data => _t('Data', 'Данные');
  String get export => _t('Export backup', 'Сохранить резервную копию');
  String get exportBody =>
      _t('JSON file + clipboard', 'Файл JSON и буфер обмена');
  String get exportBodyMobile =>
      _t('Copies JSON to the clipboard', 'Копирует JSON в буфер обмена');
  String exported(String path) =>
      _t('Saved to $path and copied', 'Сохранено в $path и скопировано');
  String get copied => _t(
    'Backup copied to the clipboard',
    'Резервная копия скопирована в буфер обмена',
  );
  String get importTitle =>
      _t('Import from clipboard', 'Загрузить из буфера обмена');
  String get importBody => _t(
    'Paste a Ledgify backup (JSON)',
    'Резервная копия Ledgify в формате JSON',
  );
  String imported(int n) =>
      _ru ? 'Загружено: ${subscriptions(n)}' : 'Imported ${subscriptions(n)}';
  String importError(String reason) => switch (reason) {
    'empty' => _t('The clipboard is empty', 'Буфер обмена пуст'),
    'not-json' => _t(
      'The clipboard does not contain JSON',
      'В буфере обмена не JSON',
    ),
    'newer-format' => _t(
      'This backup is from a newer Ledgify version',
      'Копия сделана более новой версией Ledgify',
    ),
    _ => _t('This is not a Ledgify backup', 'Это не резервная копия Ledgify'),
  };
  String get demo => _t('Add demo subscriptions', 'Добавить демо-подписки');
  String get demoBody => _t(
    '12 sample services to explore the app',
    '12 примеров, чтобы изучить приложение',
  );
  String get demoAdded =>
      _t('Demo subscriptions added', 'Демо-подписки добавлены');
  String get danger => _t('Danger zone', 'Опасная зона');
  String get deleteAll =>
      _t('Delete all subscriptions', 'Удалить все подписки');
  String deleteAllBody(int n) => _t(
    '${subscriptions(n)} on this device',
    '${subscriptions(n)} на этом устройстве',
  );
  String get deleteAllTitle => _t('Delete everything?', 'Удалить всё?');
  String get deleteAllWarning => _t(
    'All subscriptions will be removed from this device. Export a backup first if you might need them.',
    'Все подписки будут удалены с этого устройства. Если они могут понадобиться, сначала сохраните резервную копию.',
  );
  String get deleteAllConfirm => _t('Delete all', 'Удалить всё');
  String get allDeleted =>
      _t('All subscriptions deleted', 'Все подписки удалены');
  String get about => _t('About', 'О приложении');
  String version(String v) => _t('Version $v', 'Версия $v');
  String get aboutBody => _t(
    'Your data stays on this device. No accounts, no ads, no tracking.',
    'Данные хранятся только на этом устройстве. Без аккаунтов, рекламы и слежки.',
  );
  String get shortcuts => _t('Keyboard shortcuts', 'Горячие клавиши');
  List<(String, String)> get shortcutList => [
    ('Ctrl + N', add),
    ('Ctrl + F', search),
    ('Ctrl + 1 / 2 / 3', _t('Switch tabs', 'Переключить вкладки')),
    ('← / →', _t('Previous / next month', 'Предыдущий / следующий месяц')),
    ('Esc', close),
  ];

  // ── Toasts ─────────────────────────────────────────────────────────────

  String addedMsg(String n) => _t('“$n” added', '«$n» добавлена');
  String updatedMsg(String n) => _t('“$n” saved', '«$n» сохранена');
  String deletedMsg(String n) => _t('“$n” deleted', '«$n» удалена');
  String archivedMsg(String n) => _t('“$n” archived', '«$n» в архиве');
  String restoredMsg(String n) =>
      _t('“$n” restored', '«$n» возвращена из архива');

  // ── Budget dialog ──────────────────────────────────────────────────────

  String get budgetDialogBody => _t(
    'Ledgify compares it with the charges of each month.',
    'Ledgify сравнит его со списаниями каждого месяца.',
  );

  // ── Onboarding ─────────────────────────────────────────────────────────

  String get skip => _t('Skip', 'Пропустить');
  String get back => _t('Back', 'Назад');
  String get next => _t('Next', 'Далее');
  String get startFresh => _t('Start from scratch', 'Начать с нуля');
  List<(String, String)> get slides => [
    (
      _t('All subscriptions\nin one place', 'Все подписки\nв одном месте'),
      _t(
        'Streaming, cloud, gym, phone — every recurring payment and what it really costs per month.',
        'Стриминг, облако, спортзал, связь — все регулярные платежи и их реальная цена в месяц.',
      ),
    ),
    (
      _t('Know what is\ncoming', 'Знайте, что\nспишется'),
      _t(
        'A calendar of charges and reminders a few days ahead — no surprise payments.',
        'Календарь списаний и напоминания за несколько дней — без неожиданных платежей.',
      ),
    ),
    (
      _t('Keep spending\nin check', 'Держите расходы\nпод контролем'),
      _t(
        'Totals in one currency, a monthly budget and the most expensive services at a glance.',
        'Итоги в одной валюте, бюджет на месяц и самые дорогие сервисы — сразу видно.',
      ),
    ),
  ];
}

class _Delegate extends LocalizationsDelegate<S> {
  const _Delegate();

  @override
  bool isSupported(Locale locale) =>
      supportedLocales.any((l) => l.languageCode == locale.languageCode);

  @override
  Future<S> load(Locale locale) async => S(locale);

  @override
  bool shouldReload(_Delegate old) => false;
}
