import 'package:budget/database/tables.dart';
import 'package:budget/struct/cloudSync/cloudPull.dart';
import 'package:budget/struct/cloudSync/cloudPush.dart';
import 'package:budget/struct/cloudSync/cloudSyncConfig.dart';
import 'package:budget/struct/cloudSync/cloudSyncLock.dart';
import 'package:budget/struct/cloudSync/cloudSyncSession.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/widgets/globalSnackbar.dart';
import 'package:budget/widgets/navigationFramework.dart';
import 'package:budget/widgets/openSnackbar.dart';

Future<bool> runInitialCloudSync({
  CloudSyncSession? sessionOverride,
  FinanceDatabase? dbOverride,
}) async {
  return CloudSyncLock.synchronized(() async {
    try {
      final session = sessionOverride ?? await getCloudSyncSession();
      if (session == null) {
        print("Initial cloud sync skipped: no active session");
        return false;
      }

      print("Starting initial cloud sync...");
      loadingProgressKey.currentState?.setProgressPercentage(0.1);

      // 1. Reset all pull cursors to epoch to fetch everything
      for (final table in CloudTable.values) {
        await sharedPreferences.remove("cloudPullCursor_${table.name}");
      }

      // 2. Pull all remote data
      loadingProgressKey.currentState?.setProgressPercentage(0.3);
      final pullSuccess = await pullCloudChanges(
        sessionOverride: session,
        dbOverride: dbOverride,
        force: true,
      );

      if (!pullSuccess) {
        print("Initial pull failed or was interrupted");
      }

      // 3. Reset push cursor to epoch to push all local data
      await sharedPreferences.remove("cloudLastPushedAt");
      loadingProgressKey.currentState?.setProgressPercentage(0.6);

      // 4. Push all local rows to cloud
      final pushSuccess = await pushLocalChangesToCloud(
        sessionOverride: session,
        dbOverride: dbOverride,
        force: true,
      );

      if (!pushSuccess) {
        print("Initial push encountered an error");
      }

      // 5. Mark initial sync done and store synced UID
      await updateSettings("cloudInitialSyncDone", true,
          updateGlobalState: false);
      await updateSettings("cloudSyncUid", session.uid,
          updateGlobalState: false);

      loadingProgressKey.currentState?.setProgressPercentage(0);
      print("Initial cloud sync completed successfully");
      return true;
    } catch (e, stack) {
      print("Error during initial cloud sync: $e");
      print(stack);
      loadingProgressKey.currentState?.setProgressPercentage(0);
      openSnackbar(SnackbarMessage(
        title: "Cloud Sync Error",
        description: e.toString(),
      ));
      return false;
    }
  });
}
