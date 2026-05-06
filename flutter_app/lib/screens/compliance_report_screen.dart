import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ComplianceReportScreen extends StatefulWidget {
  const ComplianceReportScreen({super.key});

  @override
  State<ComplianceReportScreen> createState() => _ComplianceReportScreenState();
}

class _ComplianceReportScreenState extends State<ComplianceReportScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _reportData = [];

  @override
  void initState() {
    super.initState();
    _fetchReport();
  }

  Future<void> _fetchReport() async {
    try {
      final response = await Supabase.instance.client
          .from('dnd_compliance_report')
          .select()
          .limit(100)
          .order('call_time', ascending: false);

      if (!mounted) return;
      setState(() {
        _reportData = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Compliance report blocked.')),
      );
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DND & Consent Compliance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchReport,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reportData.isEmpty
              ? const Center(child: Text('No compliance records found.'))
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Call Time')),
                      DataColumn(label: Text('DND Status')),
                      DataColumn(label: Text('Consent')),
                      DataColumn(label: Text('Result')),
                    ],
                    rows: _reportData.map((row) {
                      final status = row['call_status'] as String;
                      final dnd = row['verified_dnd_status'] as String;
                      final consent = row['general_consent'] as String;

                      return DataRow(cells: [
                        DataCell(Text(row['call_time'].toString().substring(0, 16))),
                        DataCell(Text(dnd.toUpperCase(), style: TextStyle(color: dnd == 'clear' ? Colors.green : Colors.red))),
                        DataCell(Text(consent.toUpperCase())),
                        DataCell(Text(status.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold))),
                      ]);
                    }).toList(),
                  ),
                ),
    );
  }
}
