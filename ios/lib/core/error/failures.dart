import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  
  const Failure(this.message);

  @override
  List<Object> get props => [message];
}

// General failures
class ServerFailure extends Failure {
  const ServerFailure([String message = 'Server error occurred']) : super(message);
}

class CacheFailure extends Failure {
  const CacheFailure([String message = 'Cache error occurred']) : super(message);
}

class NetworkFailure extends Failure {
  const NetworkFailure([String message = 'Network error occurred']) : super(message);
}

// Authentication failures
class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure([String message = 'Unauthorized access']) : super(message);
}

class AuthenticationFailure extends Failure {
  const AuthenticationFailure([String message = 'Authentication failed']) : super(message);
}

// Validation failures
class ValidationFailure extends Failure {
  const ValidationFailure(String message) : super(message);
}

// Not found failures
class NotFoundFailure extends Failure {
  const NotFoundFailure([String message = 'Resource not found']) : super(message);
}

// Permission failures
class PermissionFailure extends Failure {
  const PermissionFailure([String message = 'Permission denied']) : super(message);
}

// Rate limit failures
class RateLimitFailure extends Failure {
  const RateLimitFailure([String message = 'Rate limit exceeded']) : super(message);
}

// Conflict failures
class ConflictFailure extends Failure {
  const ConflictFailure([String message = 'Conflict occurred']) : super(message);
}

// Timeout failures
class TimeoutFailure extends Failure {
  const TimeoutFailure([String message = 'Request timeout']) : super(message);
}

// Signal specific failures
class SignalNotFoundFailure extends NotFoundFailure {
  const SignalNotFoundFailure([String message = 'Signal not found']) : super(message);
}

class SignalFullFailure extends ConflictFailure {
  const SignalFullFailure([String message = 'Signal is full']) : super(message);
}

class AlreadyJoinedFailure extends ConflictFailure {
  const AlreadyJoinedFailure([String message = 'Already joined this signal']) : super(message);
}

class CannotJoinOwnSignalFailure extends ValidationFailure {
  const CannotJoinOwnSignalFailure([String message = 'Cannot join your own signal']) : super(message);
}

class InsufficientMannerScoreFailure extends ValidationFailure {
  const InsufficientMannerScoreFailure([String message = 'Manner score too low']) : super(message);
}

class InvalidLocationFailure extends ValidationFailure {
  const InvalidLocationFailure([String message = 'Invalid location coordinates']) : super(message);
}

class PastDateFailure extends ValidationFailure {
  const PastDateFailure([String message = 'Cannot schedule in the past']) : super(message);
}

class DailyLimitExceededFailure extends ValidationFailure {
  const DailyLimitExceededFailure([String message = 'Daily limit exceeded']) : super(message);
}

class DuplicateSignalFailure extends ConflictFailure {
  const DuplicateSignalFailure([String message = 'Duplicate signal detected']) : super(message);
}