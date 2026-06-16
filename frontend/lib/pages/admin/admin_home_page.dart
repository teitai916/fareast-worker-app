import 'package:flutter/material.dart';
import 'package:fareast_worker_app/config/theme.dart';
import 'package:fareast_worker_app/services/api_service.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  int _currentIndex = 0;
  final _api = ApiService();

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildDashboard(),
      _buildWorkerManagement(),
      _buildBlacklistPage(),
      _buildProfilePage(),
    ];

    return Scaffold(
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: '總覽'),
          BottomNavigationBarItem(icon: Icon(Icons.people_outlined), label: '工人'),
          BottomNavigationBarItem(icon: Icon(Icons.block_outlined), label: '黑名單'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: '我的'),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    return Scaffold(
      appBar: AppBar(title: const Text('平台管理')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats Cards
            Row(
              children: [
                Expanded(child: _buildStatCard('公司', '5', Colors.blue)),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard('地盤', '12', Colors.green)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildStatCard('工人', '128', Colors.orange)),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard('黑名單', '3', Colors.red)),
              ],
            ),
            const SizedBox(height: 24),

            const Text('管理選單', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildMenuCard(Icons.business, '查看所有公司', () {}),
            _buildMenuCard(Icons.location_on, '查看所有地盤', () {}),
            _buildMenuCard(Icons.people, '查看所有工人', () {}),
            _buildMenuCard(Icons.shield, '安全分管理', () {}),
            _buildMenuCard(Icons.block, '黑名單管理', () => setState(() => _currentIndex = 2)),
            _buildMenuCard(Icons.lock_outline, '鎖卡/重開卡', () {}),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(IconData icon, String title, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: AppTheme.primaryColor),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Widget _buildWorkerManagement() {
    return Scaffold(
      appBar: AppBar(title: const Text('工人管理')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: '搜索工人姓名/編號',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          // Company/Site selector
          DropdownButtonFormField(
            decoration: InputDecoration(
              labelText: '選擇地盤',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('全部地盤')),
              DropdownMenuItem(value: '1', child: Text('九龍灣宏照道地盤')),
              DropdownMenuItem(value: '2', child: Text('荃灣海盛路地盤')),
            ],
            onChanged: (_) {},
          ),
          const SizedBox(height: 16),
          _buildWorkerCard('王大明', 'YW20241001', '九龍灣', 85, false, false),
          _buildWorkerCard('陳小華', 'YW20241002', '荃灣', 92, false, false),
          _buildWorkerCard('林志強', 'YW20241003', '九龍灣', 45, true, true),
          _buildWorkerCard('黃偉文', 'YW20241004', '沙田', 70, false, false),
        ],
      ),
    );
  }

  Widget _buildWorkerCard(String name, String id, String site, int score, bool blacklisted, bool locked) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: blacklisted ? AppTheme.errorColor : AppTheme.primaryColor,
              child: Text(name[0], style: const TextStyle(color: Colors.white)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      if (blacklisted)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.errorColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('黑名單', style: TextStyle(color: Colors.white, fontSize: 10)),
                        ),
                      if (locked)
                        Container(
                          margin: const EdgeInsets.only(left: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.warningColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('鎖卡', style: TextStyle(color: Colors.white, fontSize: 10)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('$id | $site | 安全分：$score', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            PopupMenuButton(
              itemBuilder: (context) => [
                PopupMenuItem(value: 'detail', child: Text('查看詳情')),
                PopupMenuItem(value: 'deduct', child: Text('扣分')),
                PopupMenuItem(value: 'lock', child: Text(locked ? '重開卡' : '鎖卡')),
                PopupMenuItem(value: 'blacklist', child: Text(blacklisted ? '移出黑名單' : '加入黑名單')),
              ],
              onSelected: (value) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('操作：$value')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlacklistPage() {
    return Scaffold(
      appBar: AppBar(title: const Text('黑名單管理')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ElevatedButton.icon(
            onPressed: () => _showAddBlacklistDialog(),
            icon: const Icon(Icons.person_add_alt),
            label: const Text('加入黑名單'),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const CircleAvatar(backgroundColor: AppTheme.errorColor, child: Text('林', style: TextStyle(color: Colors.white))),
              title: const Text('林志強'),
              subtitle: const Text('原因：多次違反安全規定 | 加入時間：2026-05-20'),
              trailing: TextButton(
                onPressed: () {},
                child: const Text('移出', style: TextStyle(color: AppTheme.primaryColor)),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const CircleAvatar(backgroundColor: AppTheme.errorColor, child: Text('何', style: TextStyle(color: Colors.white))),
              title: const Text('何國榮'),
              subtitle: const Text('原因：未經許可進入危險區域 | 加入時間：2026-05-15'),
              trailing: TextButton(
                onPressed: () {},
                child: const Text('移出', style: TextStyle(color: AppTheme.primaryColor)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddBlacklistDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('加入黑名單'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(labelText: '工人編號/姓名', hintText: '搜索工人'),
            ),
            const SizedBox(height: 12),
            TextField(
              maxLines: 3,
              decoration: const InputDecoration(labelText: '加入原因'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('確認加入')),
        ],
      ),
    );
  }

  Widget _buildProfilePage() {
    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
            ),
            child: Row(
              children: [
                const CircleAvatar(radius: 36, backgroundColor: AppTheme.primaryColor, child: Text('管', style: TextStyle(color: Colors.white, fontSize: 28))),
                const SizedBox(width: 16),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('管理員', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text('平台管理員', style: TextStyle(color: AppTheme.textSecondary)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildMenuItem(Icons.settings_outlined, '設置', () {}),
          _buildMenuItem(Icons.logout, '退出登入', () => Navigator.pushReplacementNamed(context, '/login'), color: AppTheme.errorColor),
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap, {Color? color}) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        leading: Icon(icon, color: color ?? AppTheme.textPrimary),
        title: Text(title, style: TextStyle(color: color ?? AppTheme.textPrimary)),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: onTap,
      ),
    );
  }
}
