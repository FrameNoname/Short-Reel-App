import 'package:flutter/foundation.dart';

import '../data/app_repository.dart';
import '../services/errors.dart';

class AdminController extends ChangeNotifier {
  AdminController(this.repository);

  final AppRepository repository;

  AdminSales sales = const AdminSales(totalUsd: 0);
  bool isLoading = false;
  String? error;

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      sales = await repository.adminSales();
    } on Object catch (e) {
      error = errorMessage(e);
    }
    isLoading = false;
    notifyListeners();
  }

  void reset() {
    sales = const AdminSales(totalUsd: 0);
    error = null;
    notifyListeners();
  }
}
