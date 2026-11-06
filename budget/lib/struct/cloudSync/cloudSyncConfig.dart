import 'package:budget/struct/settings.dart';

bool isFirestoreSyncActive() {
  return appStateSettings["cloudSyncProvider"] == "firestore" &&
      appStateSettings["cloudSyncEnabled"] == true;
}

class CloudCollections {
  static const String users = 'users';
  static const String wallets = 'wallets';
  static const String transactions = 'transactions';
  static const String categories = 'categories';
  static const String budgets = 'budgets';
  static const String categoryBudgetLimits = 'categoryBudgetLimits';
  static const String associatedTitles = 'associatedTitles';
  static const String scannerTemplates = 'scannerTemplates';
  static const String objectives = 'objectives';
  static const String deleteLogs = 'deleteLogs';
  static const String meta = 'meta';
  static const String syncMetaDoc = 'sync';
  static const String settingsMetaDoc = 'settings';
}

class CloudFields {
  static const String serverUpdatedAt = '_serverUpdatedAt';
  static const String clientId = '_clientId';
  static const String schemaVersion = '_schemaVersion';
}

enum CloudTable {
  wallets,
  transactions,
  categories,
  budgets,
  categoryBudgetLimits,
  associatedTitles,
  scannerTemplates,
  objectives,
  deleteLogs,
}

String collectionNameForTable(CloudTable table) {
  switch (table) {
    case CloudTable.wallets:
      return CloudCollections.wallets;
    case CloudTable.transactions:
      return CloudCollections.transactions;
    case CloudTable.categories:
      return CloudCollections.categories;
    case CloudTable.budgets:
      return CloudCollections.budgets;
    case CloudTable.categoryBudgetLimits:
      return CloudCollections.categoryBudgetLimits;
    case CloudTable.associatedTitles:
      return CloudCollections.associatedTitles;
    case CloudTable.scannerTemplates:
      return CloudCollections.scannerTemplates;
    case CloudTable.objectives:
      return CloudCollections.objectives;
    case CloudTable.deleteLogs:
      return CloudCollections.deleteLogs;
  }
}
