class AppConstants {
  // Database
  static const String databaseName = 'diocesan_funds.db';
  static const int databaseVersion = 6; // INCREMENTED VERSION

  static const String extractionsTable = 'extractions';
  static const String expensesTable = 'expenses';
  static const String categoriesTable = 'categories';
  static const String depositsTable = 'deposits';
  static const String fundAdvancesTable = 'fund_advances'; // NEW TABLE NAME

  static const String colId = 'id';
  static const String colName = 'name';
  static const String colCategoryId = 'category_id';
  static const String colType = 'type';
  static const String colFundAdvanceId = 'fund_advance_id'; // NEW COLUMN NAME

  static const String defaultUsername = 'obispo';
  static const String defaultPassword = '12345';

  static const String currencySymbol = 'Gs.';
  static const String currencyName = 'guaraníes';

  static const String defaultLocale = 'en_US';
  static const String spanishLocale = 'es_PY';

  // Account Configuration Keys
  static const String prefKeyConfigUnitName = 'config_main_unit_name';
  static const String prefKeyConfigUnitNumber = 'config_main_unit_number';
  static const String prefKeyConfigBishopName = 'config_bishop_name';
  static const String prefKeyConfigFirstCounselorName = 'config_first_counselor_name';
  static const String prefKeyConfigSecondCounselorName = 'config_second_counselor_name';
  static const String prefKeyConfigSecretaryName = 'config_secretary_name';
}