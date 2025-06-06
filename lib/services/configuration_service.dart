import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart'; // Ajusta la ruta si es necesario

class AccountConfig {
  final String? unitName;
  final String? unitNumber;
  final String? bishopName;
  final String? firstCounselorName;
  final String? secondCounselorName;
  final String? secretaryName;

  AccountConfig({
    this.unitName,
    this.unitNumber,
    this.bishopName,
    this.firstCounselorName,
    this.secondCounselorName,
    this.secretaryName,
  });

  bool get isFullyConfigured {
    return unitName != null && unitName!.isNotEmpty &&
           unitNumber != null && unitNumber!.isNotEmpty &&
           bishopName != null && bishopName!.isNotEmpty &&
           firstCounselorName != null && firstCounselorName!.isNotEmpty &&
           // secondCounselorName y secretaryName podrían ser opcionales según el PDF
           secondCounselorName != null && secondCounselorName!.isNotEmpty &&
           secretaryName != null && secretaryName!.isNotEmpty;
  }
}

class ConfigurationService {
  Future<void> saveAccountConfiguration({
    required String unitName,
    required String unitNumber,
    required String bishopName,
    required String firstCounselorName,
    required String secondCounselorName,
    required String secretaryName,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefKeyConfigUnitName, unitName);
    await prefs.setString(AppConstants.prefKeyConfigUnitNumber, unitNumber);
    await prefs.setString(AppConstants.prefKeyConfigBishopName, bishopName);
    await prefs.setString(AppConstants.prefKeyConfigFirstCounselorName, firstCounselorName);
    await prefs.setString(AppConstants.prefKeyConfigSecondCounselorName, secondCounselorName);
    await prefs.setString(AppConstants.prefKeyConfigSecretaryName, secretaryName);
  }

  Future<AccountConfig> getAccountConfiguration() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return AccountConfig(
      unitName: prefs.getString(AppConstants.prefKeyConfigUnitName),
      unitNumber: prefs.getString(AppConstants.prefKeyConfigUnitNumber),
      bishopName: prefs.getString(AppConstants.prefKeyConfigBishopName),
      firstCounselorName: prefs.getString(AppConstants.prefKeyConfigFirstCounselorName),
      secondCounselorName: prefs.getString(AppConstants.prefKeyConfigSecondCounselorName),
      secretaryName: prefs.getString(AppConstants.prefKeyConfigSecretaryName),
    );
  }
}