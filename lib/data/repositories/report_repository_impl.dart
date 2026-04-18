import 'package:r0/domain/models/report.dart';
import 'package:r0/domain/repositories/report_repository.dart';
import 'package:r0/data/services/database_helper.dart';

class ReportRepositoryImpl implements ReportRepository {
  final DatabaseHelper _databaseHelper;

  ReportRepositoryImpl(this._databaseHelper);

  @override
  Future<int> insertReport(Report report) {
    return _databaseHelper.insertReport(report);
  }

  @override
  Future<List<Report>> getReports() {
    return _databaseHelper.getReports();
  }

  @override
  Future<List<Report>> getReportsPage({int limit = 50, int offset = 0}) {
    return _databaseHelper.getReportsPage(limit: limit, offset: offset);
  }

  @override
  Future<List<Report>> getReportsByType(String type) {
    return _databaseHelper.getReportsByType(type);
  }

  @override
  Future<Report?> getReport(int id) {
    return _databaseHelper.getReport(id);
  }

  @override
  Future<int> updateReport(Report report) {
    return _databaseHelper.updateReport(report);
  }

  @override
  Future<void> sendReportToSheets(Report report) {
    return _databaseHelper.sendReportToSheets(report);
  }

  @override
  Future<int> deleteReport(int id) {
    return _databaseHelper.deleteReport(id);
  }

  @override
  Future<void> close() {
    return _databaseHelper.close();
  }
}
