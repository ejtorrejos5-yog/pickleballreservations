import 'dart:async';
import 'dart:math';
import '../models/user_model.dart';
import '../models/court_model.dart';
import '../models/court_status_model.dart';
import '../models/reservation_model.dart';
import '../models/tournament_model.dart';

import '../models/player_model.dart';
import '../services/tournament_service.dart';

class MockDatabase {
  MockDatabase._();

  static final List<UserModel> users = [
    const UserModel(
      uid: 'admin_user',
      name: 'EJ Torrejos (Admin)',
      email: 'admin@gmail.com',
      role: 'admin',
      phone: '09171234567',
    ),
    const UserModel(
      uid: 'player_user',
      name: 'EJ Torrejos (Player)',
      email: 'player@gmail.com',
      role: 'player',
      phone: '09189876543',
    ),
    const UserModel(
      uid: 'mock_u_3',
      name: 'Maria Santos',
      email: 'maria.santos@gmail.com',
      role: 'player',
      phone: '09205551234',
    ),
    const UserModel(
      uid: 'mock_u_4',
      name: 'Carlo Mendoza',
      email: 'carlo.mendoza@gmail.com',
      role: 'player',
      phone: '09228887766',
    ),
    const UserModel(
      uid: 'mock_u_5',
      name: 'Bianca Reyes',
      email: 'bianca.reyes@gmail.com',
      role: 'player',
      phone: '09194443322',
    ),
  ];

  static UserModel? currentUser;

  static final List<CourtModel> courts = [
    const CourtModel(
      id: 'court_1',
      name: 'Court A',
      description: 'Professional pickleball court with cushioned flooring',
      isActive: true,
    ),
    const CourtModel(
      id: 'court_2',
      name: 'Court B',
      description: 'Standard pickleball court with professional markings',
      isActive: true,
    ),
    const CourtModel(
      id: 'court_3',
      name: 'Court C',
      description: 'Outdoor court with windbreakers',
      isActive: true,
    ),
    const CourtModel(
      id: 'court_4',
      name: 'Court D',
      description: 'Standard court near clubhouse',
      isActive: true,
    )
  ];

  static final Map<String, CourtStatusModel> courtStatuses = {
    'court_1': const CourtStatusModel(courtId: 'court_1', isOccupied: false),
    'court_2': const CourtStatusModel(courtId: 'court_2', isOccupied: false),
    'court_3': const CourtStatusModel(courtId: 'court_3', isOccupied: false),
    'court_4': const CourtStatusModel(courtId: 'court_4', isOccupied: false),
  };

  static final List<ReservationModel> reservations = [];
  static final List<TournamentModel> tournaments = [];

  static final StreamController<UserModel?> authController =
      StreamController<UserModel?>.broadcast();
  static final StreamController<List<UserModel>> usersController =
      StreamController<List<UserModel>>.broadcast();
  static final StreamController<List<CourtModel>> courtsController =
      StreamController<List<CourtModel>>.broadcast();
  static final StreamController<Map<String, CourtStatusModel>>
      statusesController =
      StreamController<Map<String, CourtStatusModel>>.broadcast();
  static final StreamController<List<ReservationModel>>
      reservationsController =
      StreamController<List<ReservationModel>>.broadcast();
  static final StreamController<List<TournamentModel>>
      tournamentsController =
      StreamController<List<TournamentModel>>.broadcast();

  static Timer? _simulationTimer;

  static void init() {
    if (tournaments.isEmpty) {
      final samplePlayers = [
        const PlayerModel(uid: 'p_1', name: 'Alex Rivera', email: 'alex@gmail.com'),
        const PlayerModel(uid: 'p_2', name: 'Carlo Mendoza', email: 'carlo@gmail.com'),
        const PlayerModel(uid: 'p_3', name: 'Bianca Santos', email: 'bianca@gmail.com'),
      ];
      final service = TournamentService();
      final rounds = service.generateBracket(samplePlayers);
      tournaments.add(
        TournamentModel(
          id: 'tour_mock_1',
          name: 'Summer Smash Championship 2026',
          date: DateTime.now().add(const Duration(days: 3)),
          status: 'upcoming',
          format: 'single_elimination',
          players: samplePlayers,
          rounds: rounds,
          description: 'Open community tournament event. Players are welcome to register and compete!',
          courtId: 'court_1',
          courtName: 'Court A',
          creatorId: 'admin_user',
          creatorName: 'Club Admin',
          createdAt: DateTime.now(),
        ),
      );
    }
    publishAll();
    _startSimulation();
  }

  static void publishAll() {
    authController.add(currentUser);
    usersController.add(List.from(users));
    courtsController.add(List.from(courts));
    statusesController.add(Map.from(courtStatuses));
    reservationsController.add(List.from(reservations));
    tournamentsController.add(List.from(tournaments));
  }

  static void _startSimulation() {
    _simulationTimer?.cancel();
    // Simulate periodic IoT updates
    _simulationTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      final rand = Random();
      final courtToUpdate = courts[rand.nextInt(courts.length)];

      // Don't disturb active user reservations status
      final currentStatus = courtStatuses[courtToUpdate.id];
      if (currentStatus?.statusType == CourtStatusType.reserved) return;

      final isOccupied = rand.nextBool();
      if (isOccupied) {
        courtStatuses[courtToUpdate.id] = CourtStatusModel(
          courtId: courtToUpdate.id,
          isOccupied: true,
          reservedByName: 'Mock Player ${rand.nextInt(100)}',
          occupiedSince: DateTime.now(),
          bookedUntil: DateTime.now()
              .add(Duration(minutes: 5 + rand.nextInt(35))),
        );
      } else {
        courtStatuses[courtToUpdate.id] = CourtStatusModel(
          courtId: courtToUpdate.id,
          isOccupied: false,
        );
      }
      publishAll();
    });
  }

  static void dispose() {
    _simulationTimer?.cancel();
  }
}
