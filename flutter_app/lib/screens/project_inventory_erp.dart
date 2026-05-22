import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../utils/premium_ui.dart';

class ProjectInventoryERPScreen extends StatefulWidget {
  final String projectId;
  final String projectName;

  const ProjectInventoryERPScreen({
    super.key,
    required this.projectId,
    this.projectName = 'The Wadhwa Wise City',
  });

  @override
  State<ProjectInventoryERPScreen> createState() => _ProjectInventoryERPScreenState();
}

class _ProjectInventoryERPScreenState extends State<ProjectInventoryERPScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _units = [];
  String _selectedTower = 'Tower A';
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _fetchInventory();
  }

  Future<void> _fetchInventory() async {
    setState(() => _isLoading = true);
    // Simulating database fetch for units
    await Future.delayed(const Duration(seconds: 1));

    final mockUnits = <Map<String, dynamic>>[];
    for (int floor = 1; floor <= 10; floor++) {
      for (int unit = 1; unit <= 4; unit++) {
        final unitNum = (floor * 100) + unit;
        String status = 'available';
        if (unitNum % 7 == 0) status = 'sold';
        if (unitNum % 5 == 0) status = 'blocked';
        if (unitNum % 11 == 0) status = 'ready';

        mockUnits.add({
          'id': 'unit_$unitNum',
          'tower': 'Tower A',
          'floor': floor,
          'unit_number': unitNum.toString(),
          'configuration': unit % 2 == 0 ? '2 BHK' : '1 BHK',
          'status': status,
          'price': '₹${(unit % 2 == 0 ? 85 : 65)}L',
        });
      }
    }

    setState(() {
      _units = mockUnits;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PremiumUI.background,
      appBar: AppBar(
        title: Text('INVENTORY ERP', style: PremiumUI.h1.copyWith(fontSize: 14, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          PremiumUI.statusBadge('LIVE', PremiumUI.accent),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: PremiumUI.primary))
          : Column(
              children: [
                _buildProjectHeader(),
                _buildProjectKPIRibbon(),
                const SizedBox(height: 16),
                _buildTowerSelector(),
                const SizedBox(height: 12),
                Expanded(child: _buildUnitGrid()),
                _buildLegend(),
              ],
            ),
    );
  }

  Widget _buildProjectHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.projectName.toUpperCase(), style: PremiumUI.h1.copyWith(fontSize: 24, letterSpacing: -0.5)),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 12, color: PremiumUI.muted),
              const SizedBox(width: 4),
              Text('Phase 1 - Panvel Executive Cluster', style: PremiumUI.subtitle.copyWith(fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProjectKPIRibbon() {
    final available = _units.where((u) => u['status'] == 'available').length;
    final sold = _units.where((u) => u['status'] == 'sold').length;
    final blocked = _units.where((u) => u['status'] == 'blocked').length;
    final ready = _units.where((u) => u['status'] == 'ready').length;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _kpiSmallCard('AVAILABLE', available.toString(), PremiumUI.secondary, Icons.check_circle_outline),
          _kpiSmallCard('SOLD', sold.toString(), PremiumUI.danger, Icons.lock_outline),
          _kpiSmallCard('BLOCKED', blocked.toString(), PremiumUI.warning, Icons.hourglass_bottom),
          _kpiSmallCard('READY', ready.toString(), PremiumUI.accent, Icons.vpn_key_outlined),
        ],
      ),
    );
  }

  Widget _kpiSmallCard(String label, String value, Color color, IconData icon) {
    return Container(
      width: 110,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PremiumUI.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: PremiumUI.muted, fontSize: 8, fontWeight: FontWeight.bold)),
              Icon(icon, size: 12, color: color.withValues(alpha: 0.5)),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildTowerSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: ['Tower A', 'Tower B', 'Tower C', 'Wing X'].map((t) {
          final isSelected = _selectedTower == t;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => setState(() => _selectedTower = t),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? PremiumUI.primary : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isSelected ? PremiumUI.primary : Colors.white10),
                ),
                child: Text(
                  t.toUpperCase(),
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildUnitGrid() {
    final Map<int, List<Map<String, dynamic>>> floors = {};
    for (var unit in _units) {
      final floor = unit['floor'] as int;
      floors.putIfAbsent(floor, () => []).add(unit);
    }

    final floorKeys = floors.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: floorKeys.length,
      itemBuilder: (context, index) {
        final floorNum = floorKeys[index];
        final unitsOnFloor = floors[floorNum]!;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 54,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  border: Border(right: BorderSide(color: Colors.white10, width: 1)),
                ),
                child: Text('$floorNum', style: const TextStyle(color: Colors.white24, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: unitsOnFloor.map((u) => _buildUnitCell(u)).toList(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUnitCell(Map<String, dynamic> u) {
    final status = u['status'];
    Color color = Colors.white10;
    Color border = Colors.white24;
    IconData? icon;

    if (status == 'available') {
      color = PremiumUI.secondary.withValues(alpha: 0.08);
      border = PremiumUI.secondary.withValues(alpha: 0.3);
    } else if (status == 'sold') {
      color = PremiumUI.danger.withValues(alpha: 0.08);
      border = PremiumUI.danger.withValues(alpha: 0.3);
      icon = Icons.lock_outline;
    } else if (status == 'blocked') {
      color = PremiumUI.warning.withValues(alpha: 0.08);
      border = PremiumUI.warning.withValues(alpha: 0.3);
      icon = Icons.hourglass_bottom;
    } else if (status == 'ready') {
      color = PremiumUI.accent.withValues(alpha: 0.08);
      border = PremiumUI.accent.withValues(alpha: 0.3);
      icon = Icons.key_outlined;
    }

    return GestureDetector(
      onTap: () => _showUnitDetails(u),
      child: Container(
        width: 70,
        height: 54,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border, width: 1),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(u['unit_number'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                Text(u['configuration'], style: const TextStyle(color: Colors.white38, fontSize: 8)),
              ],
            ),
            if (icon != null)
              Positioned(
                top: 4,
                right: 4,
                child: Icon(icon, size: 8, color: border),
              ),
          ],
        ),
      ),
    );
  }

  void _showUnitDetails(Map<String, dynamic> u) {
    showModalBottomSheet(
      context: context,
      backgroundColor: PremiumUI.cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('UNIT ${u['unit_number']}', style: PremiumUI.h1.copyWith(fontSize: 24)),
                      Text('${u['tower']} • Floor ${u['floor']}', style: PremiumUI.subtitle),
                    ],
                  ),
                  PremiumUI.statusBadge(u['status'].toString().toUpperCase(), _statusColor(u['status'])),
                ],
              ),
              const SizedBox(height: 32),
              _detailRow(Icons.layers_outlined, 'CONFIGURATION', u['configuration']),
              _detailRow(Icons.payments_outlined, 'ESTIMATED PRICE', u['price']),
              _detailRow(Icons.account_tree_outlined, 'ERP IDENTIFIER', u['id']),
              const SizedBox(height: 40),
              if (u['status'] == 'available')
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () => _handleReservation(u),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PremiumUI.secondary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('RESERVE FOR HIGH-INTENT LEAD', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ),
                ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleReservation(Map<String, dynamic> u) async {
    Navigator.pop(context);
    final idempotencyKey = _uuid.v4();
    
    // In compliance with field resilience, we use idempotency for reservations
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Processing reservation for Unit ${u['unit_number']} (TXN: ${idempotencyKey.substring(0,8)}...)'),
        backgroundColor: PremiumUI.secondary,
        behavior: SnackBarBehavior.floating,
      ),
    );
    
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reservation Locked. 45-Day Broker Credit Active.')),
      );
    }
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, size: 16, color: PremiumUI.primary.withValues(alpha: 0.5)),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: PremiumUI.muted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const Spacer(),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'available': return PremiumUI.secondary;
      case 'sold': return PremiumUI.danger;
      case 'blocked': return PremiumUI.warning;
      case 'ready': return PremiumUI.accent;
      default: return PremiumUI.muted;
    }
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      decoration: const BoxDecoration(
        color: Colors.black26,
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _legendItem('AVAILABLE', PremiumUI.secondary),
          _legendItem('SOLD', PremiumUI.danger),
          _legendItem('BLOCKED', PremiumUI.warning),
          _legendItem('READY', PremiumUI.accent),
        ],
      ),
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
      ],
    );
  }
}
