import 'package:go_router/go_router.dart';
import 'package:visual_song_book/features/projection/projection_output_view.dart';
import 'package:visual_song_book/features/song_editor/song_editor_view.dart';
import 'package:visual_song_book/features/song_list/main_dashboard_page.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const MainDashboardPage(),
    ),
    GoRoute(
      path: '/projection',
      builder: (context, state) => const ProjectionOutputView(),
    ),
    GoRoute(
      path: '/song-editor',
      builder: (context, state) {
        final songIdStr = state.uri.queryParameters['id'];
        final songId = songIdStr != null ? int.tryParse(songIdStr) : null;
        return SongEditorView(songId: songId);
      },
    ),
  ],
);

final GoRouter projectionRouter = GoRouter(
  initialLocation: '/projection',
  routes: [
    GoRoute(
      path: '/projection',
      builder: (context, state) => const ProjectionOutputView(),
    ),
  ],
);
