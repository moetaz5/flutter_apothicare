import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../network/api_client.dart';
import '../services/notification_service.dart';

class MessagerieUser {
  final int id;
  final String nom;
  final String? login;
  final String? tel;
  final String? email;
  final String? photoProfil;
  final int? idRole;
  final int? idGouvernorat;
  final String? lastMessageDate;
  final String? lastMessage;

  MessagerieUser({
    required this.id,
    required this.nom,
    this.login,
    this.tel,
    this.email,
    this.photoProfil,
    this.idRole,
    this.idGouvernorat,
    this.lastMessageDate,
    this.lastMessage,
  });

  factory MessagerieUser.fromMap(Map<dynamic, dynamic> json) {
    var rawNom = (json['nom'] ?? json['username'] ?? json['login'] ?? 'Utilisateur').toString().trim();
    final parts = rawNom.split(' ');
    if (parts.isNotEmpty && parts[0].toLowerCase() == 'pharmacie' && parts.length > 1) {
      rawNom = parts.sublist(1).join(' ').trim();
    }

    int parsedId = 0;
    if (json['id'] is int) {
      parsedId = json['id'];
    } else if (json['id'] != null) {
      parsedId = int.tryParse(json['id'].toString()) ?? 0;
    } else if (json['id_user'] != null) {
      parsedId = int.tryParse(json['id_user'].toString()) ?? 0;
    }

    final rawLastDate = json['lastMessageDate'] ??
        json['last_message_date'] ??
        json['lastMessageTime'] ??
        json['date_dernier_message'] ??
        json['updatedAt'];

    final rawLastMsg = json['lastMessage'] ??
        json['last_message'] ??
        json['dernier_message'] ??
        json['message_content'];

    return MessagerieUser(
      id: parsedId,
      nom: rawNom,
      login: json['login']?.toString(),
      tel: json['tel']?.toString(),
      email: json['email']?.toString(),
      photoProfil: json['photo_profil']?.toString(),
      idRole: json['id_role'] is int ? json['id_role'] : int.tryParse(json['id_role']?.toString() ?? ''),
      idGouvernorat: json['id_gouvernorat'] is int
          ? json['id_gouvernorat']
          : int.tryParse(json['id_gouvernorat']?.toString() ?? ''),
      lastMessageDate: rawLastDate?.toString(),
      lastMessage: rawLastMsg?.toString(),
    );
  }
}

class ChatMessage {
  final int? id;
  final int idSender;
  final int idReceiver;
  final String content;
  final int lu;
  final DateTime createdAt;
  final String? fileUrl;
  final String? localPath;
  final List<int>? localBytes;

  ChatMessage({
    this.id,
    required this.idSender,
    required this.idReceiver,
    required this.content,
    required this.lu,
    required this.createdAt,
    this.fileUrl,
    this.localPath,
    this.localBytes,
  });

  factory ChatMessage.fromMap(Map<dynamic, dynamic> json) {
    DateTime parsedDate;
    try {
      final rawDate = json['createdAt'] ?? json['created_at'] ?? json['date'];
      parsedDate = rawDate != null ? DateTime.parse(rawDate.toString()) : DateTime.now();
    } catch (_) {
      parsedDate = DateTime.now();
    }

    return ChatMessage(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      idSender: json['id_sender'] is int ? json['id_sender'] : int.tryParse(json['id_sender']?.toString() ?? '') ?? 0,
      idReceiver:
          json['id_receiver'] is int ? json['id_receiver'] : int.tryParse(json['id_receiver']?.toString() ?? '') ?? 0,
      content: (json['content'] ?? json['message'] ?? json['texte'] ?? '').toString(),
      lu: json['lu'] is int ? json['lu'] : int.tryParse(json['lu']?.toString() ?? '') ?? 0,
      createdAt: parsedDate,
      fileUrl: (json['file_path'] ?? json['file_url'] ?? json['file'] ?? json['filename'])?.toString(),
    );
  }
}

class MessagerieProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();

  List<MessagerieUser> _users = [];
  Map<int, int> _unreadCounts = {};
  List<ChatMessage> _currentMessages = [];
  bool _isLoadingUsers = false;
  bool _isLoadingMessages = false;
  bool _isSending = false;
  String? _errorMessage;
  bool _hasInitialUnreadFetch = false;

  List<MessagerieUser> get users => _users;
  Map<int, int> get unreadCounts => _unreadCounts;
  List<ChatMessage> get currentMessages => _currentMessages;
  bool get isLoadingUsers => _isLoadingUsers;
  bool get isLoadingMessages => _isLoadingMessages;
  bool get isSending => _isSending;
  String? get errorMessage => _errorMessage;

  int get totalUnreadCount => _unreadCounts.values.fold(0, (sum, count) => sum + count);

  Future<void> fetchUsers({
    int? idGouvernorat,
    int? idUser,
  }) async {
    // Only show full blocking spinner if we have no users cached yet
    if (_users.isEmpty) {
      _isLoadingUsers = true;
      notifyListeners();
    }

    try {
      final payload = <String, dynamic>{};
      if (idGouvernorat != null && idGouvernorat != 0) {
        payload['id_gouvernorat'] = idGouvernorat;
      }

      final response = await _api.post('user/getUsersMessagerie', data: payload);

      List<dynamic>? rawList;
      if (response.data is List) {
        rawList = response.data as List;
      } else if (response.data is Map) {
        final map = response.data as Map;
        if (map['result'] is List) {
          rawList = map['result'] as List;
        } else if (map['data'] is List) {
          rawList = map['data'] as List;
        } else if (map['users'] is List) {
          rawList = map['users'] as List;
        }
      }

      if (rawList != null) {
        _users = rawList
            .whereType<Map>()
            .map((item) => MessagerieUser.fromMap(item))
            .where((u) => u.id != 0 && (idUser == null || u.id != idUser))
            .toList();
      }

      // Refresh unread counts in parallel without blocking
      if (idUser != null) {
        fetchUnreadCounts(idReceiver: idUser);
      }

      _isLoadingUsers = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error in fetchUsers: $e');
      _isLoadingUsers = false;
      notifyListeners();
    }
  }

  Future<void> fetchUnreadCounts({required int idReceiver, int type = 2}) async {
    try {
      final response = await _api.post('message/getUnreadCounts', data: {
        'id_receiver': idReceiver,
        'type': type,
      });

      if (response.data != null) {
        final map = <int, int>{};
        if (response.data is Map) {
          final dataMap = response.data as Map;
          dataMap.forEach((key, value) {
            final userId = int.tryParse(key.toString());
            final count = int.tryParse(value.toString()) ?? 0;
            if (userId != null && count > 0) {
              map[userId] = count;
            }
          });
        } else if (response.data is List) {
          for (final item in response.data as List) {
            if (item is Map) {
              final senderId = int.tryParse((item['id_sender'] ?? item['idSender'] ?? item['id'])?.toString() ?? '');
              final count = int.tryParse((item['count'] ?? item['unread'] ?? '1').toString()) ?? 1;
              if (senderId != null && count > 0) {
                map[senderId] = count;
              }
            }
          }
        }

        // Trigger local notification if new unread message is detected
        if (_hasInitialUnreadFetch) {
          map.forEach((senderId, count) {
            final prevCount = _unreadCounts[senderId] ?? 0;
            if (count > prevCount) {
              final sender = _users.firstWhere(
                (u) => u.id == senderId,
                orElse: () => MessagerieUser(id: senderId, nom: 'Contact Apothicare'),
              );
              NotificationService.showMessageNotification(
                senderName: sender.nom,
                message: 'Vous avez reçu un nouveau message.',
                payload: 'message',
              );
            }
          });
        }
        _hasInitialUnreadFetch = true;
        _unreadCounts = map;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error in fetchUnreadCounts: $e');
    }
  }

  Future<void> fetchMessages({
    required int idSender,
    required int idReceiver,
    int type = 2,
    bool silent = false,
  }) async {
    if (!silent && _currentMessages.isEmpty) {
      _isLoadingMessages = true;
      notifyListeners();
    }

    try {
      final response = await _api.post('message/getMessages', data: {
        'id_sender': idSender,
        'id_receiver': idReceiver,
        'type': type,
      });

      List<dynamic>? rawList;
      if (response.data is List) {
        rawList = response.data as List;
      } else if (response.data is Map) {
        final map = response.data as Map;
        if (map['result'] is List) {
          rawList = map['result'] as List;
        } else if (map['data'] is List) {
          rawList = map['data'] as List;
        } else if (map['messages'] is List) {
          rawList = map['messages'] as List;
        }
      }

      if (rawList != null) {
        _currentMessages = rawList
            .whereType<Map>()
            .map((m) => ChatMessage.fromMap(m))
            .toList();
      }

      // Mark as read
      markAsRead(idSender: idReceiver, idReceiver: idSender);

      _isLoadingMessages = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error in fetchMessages: $e');
      _isLoadingMessages = false;
      notifyListeners();
    }
  }

  Future<bool> sendMessage({
    required int idSender,
    required int idReceiver,
    required String content,
    int type = 2,
    String? filePath,
    List<int>? fileBytes,
    String? fileName,
  }) async {
    final cleanContent = content.trim();
    if (cleanContent.isEmpty && filePath == null && fileBytes == null) return false;
    _isSending = true;
    notifyListeners();

    // 1. Optimistic instant local insert for 0 latency
    final localMsg = ChatMessage(
      idSender: idSender,
      idReceiver: idReceiver,
      content: cleanContent,
      lu: 0,
      createdAt: DateTime.now(),
      fileUrl: fileName,
      localPath: filePath,
      localBytes: fileBytes,
    );
    _currentMessages.add(localMsg);
    notifyListeners();

    try {
      dynamic payload;
      if (filePath != null || fileBytes != null) {
        MultipartFile multipartFile;
        if (filePath != null) {
          multipartFile = await MultipartFile.fromFile(
            filePath,
            filename: fileName ?? filePath.split(RegExp(r'[/\\]')).last,
          );
        } else {
          multipartFile = MultipartFile.fromBytes(
            fileBytes!,
            filename: fileName ?? 'attachment',
          );
        }

        payload = FormData.fromMap({
          'id_sender': idSender,
          'id_receiver': idReceiver,
          'type': type,
          if (cleanContent.isNotEmpty) 'content': cleanContent,
          'file': multipartFile,
        });
      } else {
        payload = {
          'id_sender': idSender,
          'id_receiver': idReceiver,
          'content': cleanContent,
          'type': type,
        };
      }

      final response = await _api.post('message/sendMessage', data: payload);

      _isSending = false;
      notifyListeners();

      // Silent background sync
      fetchMessages(idSender: idSender, idReceiver: idReceiver, type: type, silent: true);
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Error in sendMessage: $e');
      _isSending = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> markAsRead({required int idSender, required int idReceiver}) async {
    try {
      _unreadCounts.remove(idSender);
      notifyListeners();
      await _api.post('message/markAsRead', data: {
        'id_sender': idSender,
        'id_receiver': idReceiver,
      });
    } catch (_) {}
  }

  void clearCurrentChat() {
    _currentMessages = [];
    notifyListeners();
  }
}
