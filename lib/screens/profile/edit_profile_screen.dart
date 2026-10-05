import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/media_social_repository.dart';

class EditProfileScreen extends StatefulWidget {
  final CreatorProfile profile;

  const EditProfileScreen({super.key, required this.profile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final MediaSocialRepository _repository = MediaSocialRepository();
  final ImagePicker _imagePicker = ImagePicker();

  late final TextEditingController _usernameController;
  late final TextEditingController _displayNameController;
  late final TextEditingController _bioController;

  final _formKey = GlobalKey<FormState>();

  bool _saving = false;
  bool _uploadingAvatar = false;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();

    _usernameController = TextEditingController(
      text: widget.profile.username ?? '',
    );
    _displayNameController = TextEditingController(
      text: widget.profile.displayName ?? '',
    );
    _bioController = TextEditingController(text: widget.profile.bio ?? '');
    _avatarUrl = widget.profile.avatarUrl?.trim();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _displayNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  String? _validateUsername(String? value) {
    final username = value?.trim().toLowerCase() ?? '';

    if (username.isEmpty) {
      return 'Choose a username.';
    }

    if (username.length < 3 || username.length > 30) {
      return 'Username must be 3–30 characters.';
    }

    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(username)) {
      return 'Use only lowercase letters, numbers, and underscores.';
    }

    return null;
  }

  Future<void> _changeProfilePhoto() async {
    if (_uploadingAvatar || _saving) return;

    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 90,
      );

      if (image == null) {
        return;
      }

      final mimeType = image.mimeType;

      if (mimeType != 'image/jpeg' &&
          mimeType != 'image/png' &&
          mimeType != 'image/webp') {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Choose a JPEG, PNG, or WebP image.')),
        );
        return;
      }

      setState(() {
        _uploadingAvatar = true;
      });

      final bytes = await image.readAsBytes();

      final newAvatarUrl = await _repository.uploadCurrentUserAvatar(
        bytes: bytes,
        contentType: mimeType!,
      );

      if (!mounted) return;

      setState(() {
        _avatarUrl = newAvatarUrl;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile photo updated.')));
    } on ProfileValidationException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update profile photo. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploadingAvatar = false;
        });
      }
    }
  }

  Future<void> _save() async {
    if (_saving) return;

    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await _repository.updateCurrentUserProfile(
        username: _usernameController.text,
        displayName: _displayNameController.text,
        bio: _bioController.text,
      );

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } on ProfileValidationException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save your profile. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = _avatarUrl;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Edit profile',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
          children: [
            Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: const Color(0xFFE7F1EC),
                    backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                        ? NetworkImage(avatarUrl)
                        : null,
                    child: avatarUrl == null || avatarUrl.isEmpty
                        ? const Icon(
                            Icons.person_outline_rounded,
                            size: 48,
                            color: Color(0xFF2E7D5B),
                          )
                        : null,
                  ),
                  if (_uploadingAvatar)
                    const Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0x66000000),
                        ),
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    right: -6,
                    bottom: -6,
                    child: Material(
                      color: const Color(0xFF2E7D5B),
                      shape: const CircleBorder(),
                      child: IconButton(
                        tooltip: 'Change profile photo',
                        onPressed: _uploadingAvatar || _saving
                            ? null
                            : _changeProfilePhoto,
                        icon: const Icon(
                          Icons.camera_alt_outlined,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: TextButton(
                onPressed: _uploadingAvatar || _saving
                    ? null
                    : _changeProfilePhoto,
                child: Text(
                  _uploadingAvatar ? 'Uploading...' : 'Change profile photo',
                ),
              ),
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _usernameController,
              enabled: !_saving,
              textCapitalization: TextCapitalization.none,
              autocorrect: false,
              maxLength: 30,
              validator: _validateUsername,
              decoration: const InputDecoration(
                labelText: 'Username',
                prefixText: '@',
                hintText: 'your_username',
                border: OutlineInputBorder(),
                helperText: '3–30 characters. Lowercase letters, numbers and underscores.',
              ),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _displayNameController,
              enabled: !_saving,
              maxLength: 50,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'Your display name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _bioController,
              enabled: !_saving,
              maxLength: 160,
              minLines: 3,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Bio',
                hintText: 'Tell people about yourself',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
