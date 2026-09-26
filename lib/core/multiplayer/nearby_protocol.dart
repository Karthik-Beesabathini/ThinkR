/// JSON wire format shared by the platform bridge (Kotlin), the
/// MethodChannel service and [NearbyHostSession].
///
/// One namespace keeps the three sides from drifting apart.
abstract final class NearbyProtocol {
  static const serviceId = 'com.thinkr.thinkr.nearby';

  // --- lobby ---------------------------------------------------------------
  static const typeHello = 'hello'; // guest → host: name + app protocol version
  static const typeWelcome = 'welcome'; // host → guest: accepted
  static const typeRejected = 'rejected'; // host → guest: room full / busy

  // --- duel setup ----------------------------------------------------------
  static const typeSetup = 'setup'; // host → guest: seed, board, patterns

  // --- duel play -----------------------------------------------------------
  static const typePattern = 'pattern'; // host → guest: pattern #N begins
  static const typeTap = 'tap'; // guest → host: player tapped a cell
  static const typeCorrect = 'correct'; // host → guest: tap was a hit
  static const typeWrong = 'wrong'; // host → guest: tap was a miss
  static const typeRound = 'round'; // host → guest: round ended
  static const typeDuelOver = 'duelOver'; // host → guest: final result
  static const typeRematch = 'rematch'; // either → other: rematch vote
  static const typeLeave = 'leave'; // either → other: clean exit
}
