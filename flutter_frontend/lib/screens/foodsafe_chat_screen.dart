import 'package:flutter/material.dart';
import '../services/api_service.dart';

class FoodSafeChatScreen extends StatefulWidget {
  final String? initialFoodType;
  final String? donationId;

  const FoodSafeChatScreen({
    super.key,
    this.initialFoodType,
    this.donationId,
  });

  @override
  State<FoodSafeChatScreen> createState() => _FoodSafeChatScreenState();
}

class _FoodSafeChatScreenState extends State<FoodSafeChatScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _foodTypeController = TextEditingController();
  bool _isLoading = false;
  bool _showQROptions = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialFoodType != null) {
      _foodTypeController.text = widget.initialFoodType!;
    }

    // Add welcome message
    _messages.add(
      ChatMessage(
        text:
            'Hello! I\'m your FoodSafe AI assistant. I can help with food safety questions, storage guidelines, and generate safety labels. Ask me anything about food safety!',
        isUser: false,
        timestamp: _formatTime(DateTime.now()),
        data: {
          'isWelcome': true,
          'sources': [
            'World Health Organization (WHO)',
            'US FDA Food Code',
            'USDA Food Safety',
            'European Food Safety Authority'
          ]
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FoodSafe AI Assistant'),
        backgroundColor: Colors.green[700],
        actions: [
          if (widget.donationId != null)
            IconButton(
              icon: const Icon(Icons.qr_code),
              onPressed: () => _showLabelOptions(),
              tooltip: 'Generate Safety Label',
            ),
          IconButton(
            icon: const Icon(Icons.checklist),
            onPressed: _getSafetyChecklist,
            tooltip: 'Safety Checklist',
          ),
        ],
      ),
      body: Column(
        children: [
          // Food type input
          Container(
            color: Colors.green[50],
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.fastfood, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _foodTypeController,
                    decoration: const InputDecoration(
                      hintText: 'Food type (e.g., chicken, dairy, leftovers)',
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // QR Options Banner
          if (_showQROptions) _buildQROptionsBanner(),

          // Chat messages
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return _buildMessage(_messages[index]);
              },
            ),
          ),

          // Input area
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildQROptionsBanner() {
    return Container(
      color: Colors.blue[50],
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(Icons.qr_code_2, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Generate Safety Label',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Create a QR code label for this food item',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _generateFoodLabel,
            child: const Text('CREATE'),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(ChatMessage message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.isUser) const Spacer(),
          CircleAvatar(
            backgroundColor: message.isUser ? Colors.blue : Colors.green,
            radius: 20,
            child: Icon(
              message.isUser ? Icons.person : Icons.food_bank,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  elevation: 2,
                  color: message.isUser ? Colors.blue[50] : Colors.green[50],
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (message.data?['isWelcome'] == true) ...[
                          const Icon(Icons.verified,
                              color: Colors.green, size: 16),
                          const SizedBox(height: 4),
                        ],
                        Text(
                          message.text,
                          style: const TextStyle(fontSize: 16),
                        ),
                        if (message.data != null &&
                            message.data?['isWelcome'] != true)
                          ..._buildAdditionalInfo(message.data!),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      message.timestamp,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    if (message.data?['confidenceScore'] != null) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.verified, color: Colors.green, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        '${(message.data!['confidenceScore'] * 100).toInt()}% confident',
                        style:
                            TextStyle(fontSize: 12, color: Colors.green[700]),
                      ),
                    ]
                  ],
                ),
              ],
            ),
          ),
          if (!message.isUser) const Spacer(),
        ],
      ),
    );
  }

  List<Widget> _buildAdditionalInfo(Map<String, dynamic> data) {
    final widgets = <Widget>[];

    if (data['safetyGuidelines'] != null) {
      widgets.addAll([
        const SizedBox(height: 12),
        const Text(
          '🚨 Critical Safety Guidelines:',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
        ),
        const SizedBox(height: 4),
        for (final guideline in data['safetyGuidelines'] as List)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text('• $guideline'),
          ),
      ]);
    }

    if (data['temperatureGuidelines'] != null) {
      widgets.addAll([
        const SizedBox(height: 8),
        const Text(
          '🌡️ Temperature Guidelines:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        for (final temp in data['temperatureGuidelines'] as List)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text('• $temp'),
          ),
      ]);
    }

    if (data['storageRecommendations'] != null) {
      widgets.addAll([
        const SizedBox(height: 8),
        const Text(
          '📦 Storage Recommendations:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        for (final rec in data['storageRecommendations'] as List)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text('• $rec'),
          ),
      ]);
    }

    if (data['timeLimits'] != null) {
      widgets.addAll([
        const SizedBox(height: 8),
        const Text(
          '⏰ Time Limits:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        for (final limit in data['timeLimits'] as List)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text('• $limit'),
          ),
      ]);
    }

    if (data['sources'] != null) {
      widgets.addAll([
        const SizedBox(height: 12),
        const Text(
          '📚 Sources & Authorities:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
        for (final source in data['sources'] as List)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Text(
              '• $source',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),
      ]);
    }

    return widgets;
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              decoration: const InputDecoration(
                hintText: 'Ask about food safety, storage, handling...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              maxLines: null,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          _isLoading
              ? const CircularProgressIndicator()
              : IconButton(
                  icon: const Icon(Icons.send, color: Colors.green),
                  onPressed: _sendMessage,
                  tooltip: 'Send question',
                ),
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(
        ChatMessage(
          text: text,
          isUser: true,
          timestamp: _formatTime(DateTime.now()),
        ),
      );
      _textController.clear();
      _isLoading = true;
      _showQROptions = true; // Show QR options after user asks a question
    });

    try {
      final apiService = ApiService();
      final response = await apiService.askFoodSafetyQuestion(
        text,
        _foodTypeController.text.trim(),
      );

      setState(() {
        _messages.add(
          ChatMessage(
            text: response['data']['answer'],
            isUser: false,
            timestamp: _formatTime(DateTime.now()),
            data: response['data'],
          ),
        );
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _messages.add(
          ChatMessage(
            text:
                'Sorry, I encountered an error. Please check your connection and try again.',
            isUser: false,
            timestamp: _formatTime(DateTime.now()),
            data: {
              'safetyGuidelines': [
                'Keep foods at safe temperatures',
                'Practice good hygiene',
                'When in doubt, throw it out'
              ]
            },
          ),
        );
        _isLoading = false;
      });
    }
  }

  Future<void> _generateFoodLabel() async {
    try {
      final apiService = ApiService();
      final response = await apiService.generateFoodLabel(
        widget.donationId ?? 'current',
        {
          'description': _foodTypeController.text.isNotEmpty
              ? _foodTypeController.text
              : 'Food Donation',
          'categories': ['donation'],
          'allergens': [],
        },
      );

      // Show label generation success
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Safety label generated successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate to label preview screen (you can implement this)
        _showLabelPreview(response['data']);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate label: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showLabelOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generate Safety Label'),
        content: const Text(
            'Create a printable QR code label with handling instructions for this food donation.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _generateFoodLabel();
            },
            child: const Text('GENERATE LABEL'),
          ),
        ],
      ),
    );
  }

  Future<void> _getSafetyChecklist() async {
    try {
      final apiService = ApiService();
      final response = await apiService.getFoodSafetyChecklist(
        _foodTypeController.text.trim(),
      );

      setState(() {
        _messages.add(
          ChatMessage(
            text:
                'Here\'s a food safety checklist for ${_foodTypeController.text.isNotEmpty ? _foodTypeController.text : 'your food items'}:',
            isUser: false,
            timestamp: _formatTime(DateTime.now()),
            data: {
              'safetyGuidelines': response['data']['checklist'],
              'sources': response['data']['sources'],
            },
          ),
        );
      });
    } catch (e) {
      // Fallback checklist
      setState(() {
        _messages.add(
          ChatMessage(
            text: 'Food Safety Checklist:',
            isUser: false,
            timestamp: _formatTime(DateTime.now()),
            data: {
              'safetyGuidelines': [
                'Check temperature: Keep below 4°C or above 60°C',
                'Inspect for unusual odors or colors',
                'Verify packaging integrity',
                'Confirm storage time limits',
                'Check for cross-contamination signs'
              ],
              'sources': ['WHO Food Safety Guidelines', 'US FDA Food Code']
            },
          ),
        );
      });
    }
  }

  void _showLabelPreview(Map<String, dynamic> labelData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Food Safety Label'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (labelData['qrCode'] != null)
                Image.network(labelData['qrCode']),
              const SizedBox(height: 16),
              Text(
                labelData['labelText'] ?? 'Safety Label',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Scan QR code for detailed handling instructions',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE'),
          ),
          ElevatedButton(
            onPressed: () {
              // Implement print functionality
              _printLabel(labelData);
            },
            child: const Text('PRINT'),
          ),
        ],
      ),
    );
  }

  void _printLabel(Map<String, dynamic> labelData) {
    // Implement printing logic here
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Print functionality would be implemented here'),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final String timestamp;
  final Map<String, dynamic>? data;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.data,
  });
}
