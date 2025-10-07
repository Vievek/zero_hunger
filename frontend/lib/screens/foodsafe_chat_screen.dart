import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';

class FoodSafeChatScreen extends StatefulWidget {
  const FoodSafeChatScreen({super.key});

  @override
  State<FoodSafeChatScreen> createState() => _FoodSafeChatScreenState();
}

class _FoodSafeChatScreenState extends State<FoodSafeChatScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _foodTypeController = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FoodSafe AI Assistant')),
      body: Column(
        children: [
          // Food type input
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _foodTypeController,
              decoration: const InputDecoration(
                labelText: 'Food Type (optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.fastfood),
              ),
            ),
          ),
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

  Widget _buildMessage(ChatMessage message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.isUser) const Spacer(),
          CircleAvatar(
            backgroundColor: message.isUser ? Colors.blue : Colors.green,
            child: Icon(
              message.isUser ? Icons.person : Icons.food_bank,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  color: message.isUser ? Colors.blue[50] : Colors.green[50],
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          message.text,
                          style: const TextStyle(fontSize: 16),
                        ),
                        if (message.data != null)
                          ..._buildAdditionalInfo(message.data!),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message.timestamp,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
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
    return [
      if (data['safetyGuidelines'] != null) ...[
        const SizedBox(height: 8),
        const Text(
          'Safety Guidelines:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        ...(data['safetyGuidelines'] as List)
            .map((guideline) => Text('• $guideline'))
            .toList(),
      ],
      if (data['storageRecommendations'] != null) ...[
        const SizedBox(height: 8),
        const Text(
          'Storage Recommendations:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        ...(data['storageRecommendations'] as List)
            .map((rec) => Text('• $rec'))
            .toList(),
      ],
      if (data['sources'] != null) ...[
        const SizedBox(height: 8),
        const Text(
          'Sources:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
        ...(data['sources'] as List)
            .map(
              (source) =>
                  Text('• $source', style: const TextStyle(fontSize: 12)),
            )
            .toList(),
      ],
    ];
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
                hintText: 'Ask about food safety...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              maxLines: null,
            ),
          ),
          const SizedBox(width: 8),
          _isLoading
              ? const CircularProgressIndicator()
              : IconButton(
                  icon: const Icon(Icons.send, color: Colors.blue),
                  onPressed: _sendMessage,
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
            text: 'Sorry, I encountered an error. Please try again.',
            isUser: false,
            timestamp: _formatTime(DateTime.now()),
          ),
        );
        _isLoading = false;
      });
    }
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
