import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_info.dart';
import '../services/adb_service.dart';
import 'app_icon_widget.dart';

class AppDrawerDialog extends StatefulWidget {
  final Function(AppInfo app) onSelectApp;
  final VoidCallback onClose;

  const AppDrawerDialog({
    super.key,
    required this.onSelectApp,
    required this.onClose,
  });

  @override
  State<AppDrawerDialog> createState() => _AppDrawerDialogState();
}

class _AppDrawerDialogState extends State<AppDrawerDialog> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Automatically select the search bar when the app menu is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
        _searchController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _searchController.text.length,
        );
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _openFirstMatchingApp(
      String val, List<AppInfo> allApps, List<AppInfo> filtered) {
    final query = val.trim().toLowerCase();
    final matches = allApps.where((app) {
      return app.name.toLowerCase().contains(query) ||
          app.packageName.toLowerCase().contains(query);
    }).toList();

    final target = matches.isNotEmpty
        ? matches.first
        : (filtered.isNotEmpty ? filtered.first : null);
    if (target != null) {
      widget.onSelectApp(target);
      widget.onClose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final adb = AdbService();
    final allApps = adb.installedApps;

    final filtered = allApps.where((app) {
      return app.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          app.packageName.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return GestureDetector(
      onTap: widget.onClose,
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: Colors.black.withOpacity(0.4),
        alignment: Alignment.bottomLeft,
        padding: const EdgeInsets.only(left: 16, bottom: 60),
        child: GestureDetector(
          onTap: () {}, // Prevent closing when clicking inside drawer
          child: Container(
            width: 580,
            height: 520,
            decoration: BoxDecoration(
              color: const Color(0xFF131824).withOpacity(0.96),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF2A364F), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.6),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              children: [
                // Header with Search and Categories
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Column(
                    children: [
                      // Search Bar
                      Focus(
                        onKeyEvent: (node, event) {
                          if (event is KeyDownEvent &&
                              (event.logicalKey == LogicalKeyboardKey.enter ||
                                  event.logicalKey ==
                                      LogicalKeyboardKey.numpadEnter)) {
                            _openFirstMatchingApp(
                                _searchController.text, allApps, filtered);
                            return KeyEventResult.handled;
                          }
                          return KeyEventResult.ignored;
                        },
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          autofocus: true,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (val) =>
                              _openFirstMatchingApp(val, allApps, filtered),
                          onChanged: (val) =>
                              setState(() => _searchQuery = val),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Search installed apps...',
                            hintStyle: const TextStyle(
                                color: Color(0xFF64748B), fontSize: 13),
                            prefixIcon: const Icon(Icons.search_rounded,
                                color: Color(0xFF94A3B8), size: 18),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded,
                                        size: 16, color: Color(0xFF94A3B8)),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: const Color(0xFF1C2436),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  const BorderSide(color: Color(0xFF334155)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  const BorderSide(color: Color(0xFF2A374E)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                  color: Color(0xFF3B82F6), width: 1.5),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1, color: Color(0xFF232D3F)),

                // Apps Grid
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.apps_outage_rounded,
                                  size: 36, color: Color(0xFF475569)),
                              const SizedBox(height: 8),
                              Text(
                                allApps.isEmpty
                                    ? 'Loading apps from phone...'
                                    : 'No apps match "$_searchQuery"',
                                style: const TextStyle(
                                    color: Color(0xFF64748B), fontSize: 13),
                              ),
                            ],
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 5,
                            childAspectRatio: 0.85,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 14,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final app = filtered[index];
                            return _buildAppItem(app);
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppItem(AppInfo app) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          widget.onSelectApp(app);
          widget.onClose();
        },
        borderRadius: BorderRadius.circular(12),
        hoverColor: const Color(0xFF2563EB).withOpacity(0.15),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppIconWidget(
                app: app,
                size: 52,
                borderRadius: 15,
              ),
              const SizedBox(height: 8),
              Text(
                app.name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFE2E8F0),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
