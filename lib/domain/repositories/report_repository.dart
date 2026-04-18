import 'package:r0/domain/models/report.dart';

abstract class ReportRepository {
  Future<int> insertReport(Report report);
  Future<List<Report>> getReports();
  Future<List<Report>> getReportsPage({int limit = 50, int offset = 0});
  Future<List<Report>> getReportsByType(String type);
  Future<Report?> getReport(int id);
  Future<int> updateReport(Report report);
  Future<void> sendReportToSheets(Report report);
  Future<int> deleteReport(int id);
  Future<void> close();
}
