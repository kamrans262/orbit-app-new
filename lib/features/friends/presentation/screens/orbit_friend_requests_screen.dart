import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/app_screen_header.dart';
import '../../../home/domain/models/home_models.dart';
import '../../../home/presentation/widgets/favorite_person_tile.dart';
import '../../data/orbit_social_repository.dart';

class OrbitFriendRequestsScreen extends StatefulWidget {
  const OrbitFriendRequestsScreen({super.key, this.repository});
  final OrbitSocialRepository? repository;
  @override
  State<OrbitFriendRequestsScreen> createState() => _OrbitFriendRequestsScreenState();
}

class _OrbitFriendRequestsScreenState extends State<OrbitFriendRequestsScreen> {
  late final OrbitSocialRepository _repo = widget.repository ?? OrbitSocialRepository();
  String _direction = 'incoming';
  List<OrbitFriendRequest> _requests = const [];
  bool _busy = false;
  bool _hasMore = false;
  String? _error;
  int _page = 0;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (_busy) return;
    final requestId = ++_generation;
    setState(() { _busy = true; _error = null; });
    try {
      final result = await _repo.requests(_direction, page: reset ? 1 : _page + 1);
      if (!mounted || requestId != _generation) return;
      setState(() {
        final list = reset ? <OrbitFriendRequest>[] : List<OrbitFriendRequest>.of(_requests);
        final known = list.map((e) => e.id).toSet();
        list.addAll(result.items.where((e) => known.add(e.id)));
        _requests = list;
        _page = result.page;
        _hasMore = result.hasMore;
      });
    } catch (_) {
      if (mounted && requestId == _generation) {
        setState(() => _error = 'Friend requests could not be loaded. Try again.');
      }
    } finally {
      if (mounted && requestId == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _action(OrbitFriendRequest request, String action) async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      await _repo.respond(request.id, action);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(action == 'accept' ? 'Friend request accepted.' :
            action == 'decline' ? 'Request declined.' : 'Request cancelled.')));
        // Revalidate response state before drawing a different relationship.
        setState(() => _busy = false);
        await _load(reset: true);
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Action was not saved. Please retry.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _select(String direction) {
    if (direction == _direction) return;
    setState(() { _direction = direction; _requests = const []; _page = 0; _hasMore = false; });
    _generation++;
    _busy = false;
    _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: Column(children: [
        Padding(padding: const EdgeInsets.all(20),
          child: AppScreenHeader(title:'Friend Requests')),
        Padding(padding: const EdgeInsets.symmetric(horizontal:20),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value:'incoming', label:Text('Received')),
              ButtonSegment(value:'outgoing', label:Text('Sent')),
            ],
            selected: {_direction},
            onSelectionChanged: (items) => _select(items.first))),
        const SizedBox(height:16),
        Expanded(child: ListView(
          padding: const EdgeInsets.symmetric(horizontal:20,vertical:8),
          children: [
            if (_busy) const Center(child:CircularProgressIndicator()),
            if (_error != null) ...[
              Text(_error!,textAlign:TextAlign.center),
              TextButton(onPressed: () => _load(reset:true),child:const Text('Retry')),
            ],
            if (!_busy && _error == null && _requests.isEmpty)
              const Padding(padding: EdgeInsets.all(20),
                child: Text('No pending requests.',textAlign:TextAlign.center)),
            for (final request in _requests) ...[
              FavoritePersonTile(
                data: FavoritePersonData(
                  id:request.person.id,name:request.person.name,
                  status:request.person.username.isEmpty ? '' : '@${request.person.username}',
                  imagePath:'',isFavorite:false),
                onTap: () {},
                onFavoritePressed: () {},
                showFavoriteAction:false),
              const SizedBox(height:6),
              Row(mainAxisAlignment: MainAxisAlignment.end,children: [
                if (_direction == 'incoming') ...[
                  TextButton(onPressed:_busy ? null:()=>_action(request,'decline'),
                    child: const Text('Decline')),
                  const SizedBox(width:8),
                  TextButton(onPressed:_busy ? null:()=>_action(request,'accept'),
                    child: const Text('Accept')),
                ] else TextButton(
                  onPressed:_busy ? null:()=>_action(request,'cancel'),
                  child:const Text('Cancel request')),
              ]),
              const SizedBox(height:10),
            ],
            if (_hasMore) Center(child:TextButton(
              onPressed:_busy ? null:()=>_load(),
              child:const Text('Load more'))),
          ],
        )),
      ])),
    );
  }
}
