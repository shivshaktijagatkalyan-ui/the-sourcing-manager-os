import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BrokerLeaderboardScreen extends StatefulWidget {
  const BrokerLeaderboardScreen({super.key});

  @override
  State<BrokerLeaderboardScreen> createState() => _BrokerLeaderboardScreenState();
}

class _BrokerLeaderboardScreenState extends State<BrokerLeaderboardScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _leaderboard = [];

  @override
  void initState() {
    super.initState();
    _fetchLeaderboard();
  }

  Future<void> _fetchLeaderboard() async {
    try {
      final response = await Supabase.instance.client
          .from('broker_leaderboard')
          .select()
          .order('marketplace_rank', ascending: true);

      if (!mounted) return;
      setState(() {
        _leaderboard = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Leaderboard blocked.')),
      );
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Broker Marketplace Leaderboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchLeaderboard,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _leaderboard.isEmpty
              ? const Center(child: Text('No public rankings available.'))
              : ListView.builder(
                  itemCount: _leaderboard.length,
                  itemBuilder: (context, index) {
                    final row = _leaderboard[index];
                    final rank = row['marketplace_rank'] as int;
                    final score = row['trust_score'] as double;
                    final visits = row['verified_visits'] as int;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: rank <= 3 ? Colors.amber : Colors.blueGrey,
                          child: Text('#$rank', style: const TextStyle(color: Colors.white)),
                        ),
                        title: Text('Broker ID: ${row['broker_id'].toString().substring(0, 8)}...'),
                        subtitle: Text('Verified Visits: $visits'),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              score.toStringAsFixed(2),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: score >= 4.0 ? Colors.green : Colors.orange,
                              ),
                            ),
                            const Text('Trust Score', style: TextStyle(fontSize: 10)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
