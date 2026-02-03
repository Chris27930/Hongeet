import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hongit/features/settings/about_screen.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/glass_container.dart';
import '../../core/utils/glass_page.dart';
import '../../data/api/local_backend_api.dart';
import '../../core/utils/audio_player_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return GlassPage(
      child: ListView(
        children: [
          const Text(
            'Settings',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          GlassContainer(
            child: ListTile(
              leading: Icon(themeProvider.useGlassTheme
                  ? CupertinoIcons.heart_circle
                  : Icons.favorite_border),
              title: const Text('Backend Health'),
              subtitle: const Text('Tap to test local server'),
              onTap: () async {
                final res = await LocalBackendApi.health();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(res.toString())),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          GlassContainer(
            child: ListTile(
              leading: Icon(themeProvider.useGlassTheme
                  ? CupertinoIcons.arrow_down_circle
                  : Icons.downloading),
              title: const Text('Download Health'),
              subtitle: const Text('Tap to test download server'),
              onTap: () async {
                try {
                  await LocalBackendApi.downloadSaavn(
                    title: 'Downloads Working!',
                    songId: '1ZDlyUiL',
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Download queued!')),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Download failed: $e')),
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 12),
          GlassContainer(
            child: SwitchListTile(
              value: themeProvider.useGlassTheme,
              onChanged: (_) => themeProvider.toggleTheme(),
              title: const Text('Glass UI Theme'),
              subtitle: const Text(
                  'Use iOS 26 glass UI Theme. Might be laggy in some low-end mobiles.'),
            ),
          ),
          const SizedBox(height: 12),
          GlassContainer(
            child: SwitchListTile(
              value: true,
              onChanged: (_) {},
              title: const Text('Saavn Service'),
              subtitle: const Text('Use Saavn as the music Service'),
            ),
          ),
          const SizedBox(height: 12),
          GlassContainer(
            child: SwitchListTile(
              value: false,
              onChanged: (_) {},
              title: const Text('Youtube Service'),
              subtitle: const Text('Use Youtube as the music Service'),
            ),
          ),
          const SizedBox(height: 12),
          GlassContainer(
            child: ListTile(
              leading: const Icon(Icons.cached),
              title: const Text('Clear stream cache'),
              subtitle: const Text('Temporary streaming data'),
              onTap: () {
                if (AudioPlayerService().isPlaying) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Pause playback before clearing cache'),
                    ),
                  );
                  return;
                }
                AudioPlayerService().clearStreamCache();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Stream cache cleared')),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          GlassContainer(
            child: ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Clear recently played'),
              subtitle: const Text('Removes playback history'),
              onTap: () async {
                await AudioPlayerService().clearRecentlyPlayed();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Recently played cleared'),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          GlassContainer(
            child: ListTile(
              leading: Icon(themeProvider.useGlassTheme
                  ? CupertinoIcons.info_circle
                  : Icons.info_outline),
              title: const Text('About'),
              subtitle: const Text('Version, licenses'),
              trailing: Icon(themeProvider.useGlassTheme
                  ? CupertinoIcons.right_chevron
                  : Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AboutScreen()),
                );
              },
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}
