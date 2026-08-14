import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:employer_kariger_app/core/theme.dart';
import 'package:employer_kariger_app/screens/dashboard/home_screen.dart';
import 'package:employer_kariger_app/screens/dashboard/notifications_screen.dart';
import 'package:employer_kariger_app/screens/jobs/jobs_screen.dart';
import 'package:employer_kariger_app/screens/jobs/post_job_screen.dart';
import 'package:employer_kariger_app/screens/profile/profile_screen.dart';
import 'package:employer_kariger_app/screens/workers/workers_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int index = 0;
  final pages = const [
    HomeScreen(),
    JobsScreen(),
    SizedBox(),
    WorkersScreen(),
    ProfileScreen(),
  ];
  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(index: index, children: pages),
    bottomNavigationBar: _BottomNav(
      selectedIndex: index,
      onSelected: (i) {
        if (i == 2) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PostJobScreen()),
          );
          return;
        }
        setState(() => index = i);
      },
    ),
  );
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.selectedIndex, required this.onSelected});
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const items = [
    (LucideIcons.house, 'Home'),
    (LucideIcons.briefcaseBusiness, 'My Jobs'),
    (LucideIcons.plus, 'Post'),
    (LucideIcons.usersRound, 'Workers'),
    (LucideIcons.building2, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      height: 78,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: List.generate(items.length, (i) {
          final selected = selectedIndex == i;
          final center = i == 2;
          return Expanded(
            child: InkWell(
              onTap: () => onSelected(i),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (center)
                    Transform.translate(
                      offset: const Offset(0, -9),
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x45F4470F),
                              blurRadius: 12,
                              offset: Offset(0, 5),
                            ),
                          ],
                        ),
                        child: const Icon(
                          LucideIcons.plus,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    )
                  else
                    Icon(
                      items[i].$1,
                      size: 22,
                      color: selected ? AppColors.primary : AppColors.muted2,
                    ),
                  SizedBox(height: center ? 1 : 5),
                  Text(
                    items[i].$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? AppColors.primary : AppColors.muted2,
                      fontSize: 10.5,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    ),
  );
}

void openNotifications(BuildContext context) => Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => const NotificationsScreen()),
);
