import 'package:dio/dio.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

@immutable
abstract class NetworkExceptions {
  const NetworkExceptions();

  const factory NetworkExceptions.requestCancelled() = RequestCancelled;
  const factory NetworkExceptions.unauthorisedRequest() = UnauthorisedRequest;
  const factory NetworkExceptions.badRequest() = BadRequest;
  const factory NetworkExceptions.notFound(String reason) = NotFound;
  const factory NetworkExceptions.methodNotAllowed() = MethodNotAllowed;
  const factory NetworkExceptions.notAcceptable() = NotAcceptable;
  const factory NetworkExceptions.requestTimeout() = RequestTimeout;
  const factory NetworkExceptions.sendTimeout() = SendTimeout;
  const factory NetworkExceptions.conflict() = Conflict;
  const factory NetworkExceptions.internalServerError() = InternalServerError;
  const factory NetworkExceptions.notImplemented() = NotImplemented;
  const factory NetworkExceptions.serviceUnavailable() = ServiceUnavailable;
  const factory NetworkExceptions.noInternetConnection() = NoInternetConnection;
  const factory NetworkExceptions.formatException() = FormatException;
  const factory NetworkExceptions.unableToProcess() = UnableToProcess;
  const factory NetworkExceptions.defaultError() = DefaultError;
  const factory NetworkExceptions.unexpectedError() = UnexpectedError;

  static NetworkExceptions getDioException(error) {
    if (error is Exception) {
      try {
        NetworkExceptions networkExceptions;
        if (error is DioException) {
          switch (error.type) {
            case DioExceptionType.cancel:
              networkExceptions = const NetworkExceptions.requestCancelled();
              break;
            case DioExceptionType.connectionTimeout:
              networkExceptions = const NetworkExceptions.requestTimeout();
              break;
            case DioExceptionType.sendTimeout:
              networkExceptions = const NetworkExceptions.sendTimeout();
              break;
            case DioExceptionType.receiveTimeout:
              networkExceptions = const NetworkExceptions.sendTimeout();
              break;
            case DioExceptionType.badResponse:
              switch (error.response?.statusCode) {
                case 400:
                  networkExceptions = const NetworkExceptions.unauthorisedRequest();
                  break;
                case 401:
                  networkExceptions = const NetworkExceptions.unauthorisedRequest();
                  break;
                case 403:
                  networkExceptions = const NetworkExceptions.unauthorisedRequest();
                  break;
                case 404:
                  networkExceptions = const NetworkExceptions.notFound("Not found");
                  break;
                case 409:
                  networkExceptions = const NetworkExceptions.conflict();
                  break;
                case 408:
                  networkExceptions = const NetworkExceptions.requestTimeout();
                  break;
                case 500:
                  networkExceptions = const NetworkExceptions.internalServerError();
                  break;
                case 503:
                  networkExceptions = const NetworkExceptions.serviceUnavailable();
                  break;
                default:
                  var responseCode = error.response?.statusCode;
                  networkExceptions = NetworkExceptions.defaultError();
                  break;
              }
              break;
            case DioExceptionType.unknown:
              if (error.message!.contains("SocketException")) {
                networkExceptions = const NetworkExceptions.noInternetConnection();
              } else {
                networkExceptions = const NetworkExceptions.unexpectedError();
              }
              break;
            default:
              networkExceptions = const NetworkExceptions.unexpectedError();
              break;
          }
        } else if (error is SocketException) {
          networkExceptions = const NetworkExceptions.noInternetConnection();
        } else {
          networkExceptions = const NetworkExceptions.unexpectedError();
        }
        return networkExceptions;
      } on FormatException catch (e) {
        return const NetworkExceptions.formatException();
      } catch (_) {
        return const NetworkExceptions.unexpectedError();
      }
    } else {
      if (error.toString().contains("is not a subtype of")) {
        return const NetworkExceptions.unableToProcess();
      } else {
        return const NetworkExceptions.unexpectedError();
      }
    }
  }

  static String getErrorMessage(NetworkExceptions networkExceptions) {
    var errorMessage = "";
    networkExceptions.when(
      notImplemented: () {
        errorMessage = "Not Implemented";
      },
      requestCancelled: () {
        errorMessage = "Request Cancelled";
      },
      internalServerError: () {
        errorMessage = "Internal Server Error";
      },
      notFound: (String reason) {
        errorMessage = reason;
      },
      serviceUnavailable: () {
        errorMessage = "Service unavailable";
      },
      methodNotAllowed: () {
        errorMessage = "Method Allowed";
      },
      badRequest: () {
        errorMessage = "Bad request";
      },
      unauthorisedRequest: () {
        errorMessage = "Unauthorised request";
      },
      unexpectedError: () {
        errorMessage = "Unexpected error occurred";
      },
      requestTimeout: () {
        errorMessage = "Connection request timeout";
      },
      noInternetConnection: () {
        errorMessage = "No internet connection";
      },
      conflict: () {
        errorMessage = "Error due to a conflict";
      },
      sendTimeout: () {
        errorMessage = "Send timeout in connection with API server";
      },
      unableToProcess: () {
        errorMessage = "Unable to process the data";
      },
      defaultError: () {
        errorMessage = "Something went wrong";
      },
      formatException: () {
        errorMessage = "Unexpected error occurred";
      },
      notAcceptable: () {
        errorMessage = "Not acceptable";
      },
    );
    return errorMessage;
  }
}

class RequestCancelled extends NetworkExceptions {
  const RequestCancelled();

  @override
  R when<R>({
    required R Function() requestCancelled,
    required R Function() unauthorisedRequest,
    required R Function() badRequest,
    required R Function(String reason) notFound,
    required R Function() methodNotAllowed,
    required R Function() notAcceptable,
    required R Function() requestTimeout,
    required R Function() sendTimeout,
    required R Function() conflict,
    required R Function() internalServerError,
    required R Function() notImplemented,
    required R Function() serviceUnavailable,
    required R Function() noInternetConnection,
    required R Function() formatException,
    required R Function() unableToProcess,
    required R Function() defaultError,
    required R Function() unexpectedError,
  }) => requestCancelled();
}

class UnauthorisedRequest extends NetworkExceptions {
  const UnauthorisedRequest();

  @override
  R when<R>({
    required R Function() requestCancelled,
    required R Function() unauthorisedRequest,
    required R Function() badRequest,
    required R Function(String reason) notFound,
    required R Function() methodNotAllowed,
    required R Function() notAcceptable,
    required R Function() requestTimeout,
    required R Function() sendTimeout,
    required R Function() conflict,
    required R Function() internalServerError,
    required R Function() notImplemented,
    required R Function() serviceUnavailable,
    required R Function() noInternetConnection,
    required R Function() formatException,
    required R Function() unableToProcess,
    required R Function() defaultError,
    required R Function() unexpectedError,
  }) => unauthorisedRequest();
}

class BadRequest extends NetworkExceptions {
  const BadRequest();

  @override
  R when<R>({
    required R Function() requestCancelled,
    required R Function() unauthorisedRequest,
    required R Function() badRequest,
    required R Function(String reason) notFound,
    required R Function() methodNotAllowed,
    required R Function() notAcceptable,
    required R Function() requestTimeout,
    required R Function() sendTimeout,
    required R Function() conflict,
    required R Function() internalServerError,
    required R Function() notImplemented,
    required R Function() serviceUnavailable,
    required R Function() noInternetConnection,
    required R Function() formatException,
    required R Function() unableToProcess,
    required R Function() defaultError,
    required R Function() unexpectedError,
  }) => badRequest();
}

class NotFound extends NetworkExceptions {
  final String reason;
  const NotFound(this.reason);

  @override
  R when<R>({
    required R Function() requestCancelled,
    required R Function() unauthorisedRequest,
    required R Function() badRequest,
    required R Function(String reason) notFound,
    required R Function() methodNotAllowed,
    required R Function() notAcceptable,
    required R Function() requestTimeout,
    required R Function() sendTimeout,
    required R Function() conflict,
    required R Function() internalServerError,
    required R Function() notImplemented,
    required R Function() serviceUnavailable,
    required R Function() noInternetConnection,
    required R Function() formatException,
    required R Function() unableToProcess,
    required R Function() defaultError,
    required R Function() unexpectedError,
  }) => notFound(reason);
}

class MethodNotAllowed extends NetworkExceptions {
  const MethodNotAllowed();

  @override
  R when<R>({
    required R Function() requestCancelled,
    required R Function() unauthorisedRequest,
    required R Function() badRequest,
    required R Function(String reason) notFound,
    required R Function() methodNotAllowed,
    required R Function() notAcceptable,
    required R Function() requestTimeout,
    required R Function() sendTimeout,
    required R Function() conflict,
    required R Function() internalServerError,
    required R Function() notImplemented,
    required R Function() serviceUnavailable,
    required R Function() noInternetConnection,
    required R Function() formatException,
    required R Function() unableToProcess,
    required R Function() defaultError,
    required R Function() unexpectedError,
  }) => methodNotAllowed();
}

class NotAcceptable extends NetworkExceptions {
  const NotAcceptable();

  @override
  R when<R>({
    required R Function() requestCancelled,
    required R Function() unauthorisedRequest,
    required R Function() badRequest,
    required R Function(String reason) notFound,
    required R Function() methodNotAllowed,
    required R Function() notAcceptable,
    required R Function() requestTimeout,
    required R Function() sendTimeout,
    required R Function() conflict,
    required R Function() internalServerError,
    required R Function() notImplemented,
    required R Function() serviceUnavailable,
    required R Function() noInternetConnection,
    required R Function() formatException,
    required R Function() unableToProcess,
    required R Function() defaultError,
    required R Function() unexpectedError,
  }) => notAcceptable();
}

class RequestTimeout extends NetworkExceptions {
  const RequestTimeout();

  @override
  R when<R>({
    required R Function() requestCancelled,
    required R Function() unauthorisedRequest,
    required R Function() badRequest,
    required R Function(String reason) notFound,
    required R Function() methodNotAllowed,
    required R Function() notAcceptable,
    required R Function() requestTimeout,
    required R Function() sendTimeout,
    required R Function() conflict,
    required R Function() internalServerError,
    required R Function() notImplemented,
    required R Function() serviceUnavailable,
    required R Function() noInternetConnection,
    required R Function() formatException,
    required R Function() unableToProcess,
    required R Function() defaultError,
    required R Function() unexpectedError,
  }) => requestTimeout();
}

class SendTimeout extends NetworkExceptions {
  const SendTimeout();

  @override
  R when<R>({
    required R Function() requestCancelled,
    required R Function() unauthorisedRequest,
    required R Function() badRequest,
    required R Function(String reason) notFound,
    required R Function() methodNotAllowed,
    required R Function() notAcceptable,
    required R Function() requestTimeout,
    required R Function() sendTimeout,
    required R Function() conflict,
    required R Function() internalServerError,
    required R Function() notImplemented,
    required R Function() serviceUnavailable,
    required R Function() noInternetConnection,
    required R Function() formatException,
    required R Function() unableToProcess,
    required R Function() defaultError,
    required R Function() unexpectedError,
  }) => sendTimeout();
}

class Conflict extends NetworkExceptions {
  const Conflict();

  @override
  R when<R>({
    required R Function() requestCancelled,
    required R Function() unauthorisedRequest,
    required R Function() badRequest,
    required R Function(String reason) notFound,
    required R Function() methodNotAllowed,
    required R Function() notAcceptable,
    required R Function() requestTimeout,
    required R Function() sendTimeout,
    required R Function() conflict,
    required R Function() internalServerError,
    required R Function() notImplemented,
    required R Function() serviceUnavailable,
    required R Function() noInternetConnection,
    required R Function() formatException,
    required R Function() unableToProcess,
    required R Function() defaultError,
    required R Function() unexpectedError,
  }) => conflict();
}

class InternalServerError extends NetworkExceptions {
  const InternalServerError();

  @override
  R when<R>({
    required R Function() requestCancelled,
    required R Function() unauthorisedRequest,
    required R Function() badRequest,
    required R Function(String reason) notFound,
    required R Function() methodNotAllowed,
    required R Function() notAcceptable,
    required R Function() requestTimeout,
    required R Function() sendTimeout,
    required R Function() conflict,
    required R Function() internalServerError,
    required R Function() notImplemented,
    required R Function() serviceUnavailable,
    required R Function() noInternetConnection,
    required R Function() formatException,
    required R Function() unableToProcess,
    required R Function() defaultError,
    required R Function() unexpectedError,
  }) => internalServerError();
}

class NotImplemented extends NetworkExceptions {
  const NotImplemented();

  @override
  R when<R>({
    required R Function() requestCancelled,
    required R Function() unauthorisedRequest,
    required R Function() badRequest,
    required R Function(String reason) notFound,
    required R Function() methodNotAllowed,
    required R Function() notAcceptable,
    required R Function() requestTimeout,
    required R Function() sendTimeout,
    required R Function() conflict,
    required R Function() internalServerError,
    required R Function() notImplemented,
    required R Function() serviceUnavailable,
    required R Function() noInternetConnection,
    required R Function() formatException,
    required R Function() unableToProcess,
    required R Function() defaultError,
    required R Function() unexpectedError,
  }) => notImplemented();
}

class ServiceUnavailable extends NetworkExceptions {
  const ServiceUnavailable();

  @override
  R when<R>({
    required R Function() requestCancelled,
    required R Function() unauthorisedRequest,
    required R Function() badRequest,
    required R Function(String reason) notFound,
    required R Function() methodNotAllowed,
    required R Function() notAcceptable,
    required R Function() requestTimeout,
    required R Function() sendTimeout,
    required R Function() conflict,
    required R Function() internalServerError,
    required R Function() notImplemented,
    required R Function() serviceUnavailable,
    required R Function() noInternetConnection,
    required R Function() formatException,
    required R Function() unableToProcess,
    required R Function() defaultError,
    required R Function() unexpectedError,
  }) => serviceUnavailable();
}

class NoInternetConnection extends NetworkExceptions {
  const NoInternetConnection();

  @override
  R when<R>({
    required R Function() requestCancelled,
    required R Function() unauthorisedRequest,
    required R Function() badRequest,
    required R Function(String reason) notFound,
    required R Function() methodNotAllowed,
    required R Function() notAcceptable,
    required R Function() requestTimeout,
    required R Function() sendTimeout,
    required R Function() conflict,
    required R Function() internalServerError,
    required R Function() notImplemented,
    required R Function() serviceUnavailable,
    required R Function() noInternetConnection,
    required R Function() formatException,
    required R Function() unableToProcess,
    required R Function() defaultError,
    required R Function() unexpectedError,
  }) => noInternetConnection();
}

class FormatException extends NetworkExceptions {
  const FormatException();

  @override
  R when<R>({
    required R Function() requestCancelled,
    required R Function() unauthorisedRequest,
    required R Function() badRequest,
    required R Function(String reason) notFound,
    required R Function() methodNotAllowed,
    required R Function() notAcceptable,
    required R Function() requestTimeout,
    required R Function() sendTimeout,
    required R Function() conflict,
    required R Function() internalServerError,
    required R Function() notImplemented,
    required R Function() serviceUnavailable,
    required R Function() noInternetConnection,
    required R Function() formatException,
    required R Function() unableToProcess,
    required R Function() defaultError,
    required R Function() unexpectedError,
  }) => formatException();
}

class UnableToProcess extends NetworkExceptions {
  const UnableToProcess();

  @override
  R when<R>({
    required R Function() requestCancelled,
    required R Function() unauthorisedRequest,
    required R Function() badRequest,
    required R Function(String reason) notFound,
    required R Function() methodNotAllowed,
    required R Function() notAcceptable,
    required R Function() requestTimeout,
    required R Function() sendTimeout,
    required R Function() conflict,
    required R Function() internalServerError,
    required R Function() notImplemented,
    required R Function() serviceUnavailable,
    required R Function() noInternetConnection,
    required R Function() formatException,
    required R Function() unableToProcess,
    required R Function() defaultError,
    required R Function() unexpectedError,
  }) => unableToProcess();
}

class DefaultError extends NetworkExceptions {
  const DefaultError();

  @override
  R when<R>({
    required R Function() requestCancelled,
    required R Function() unauthorisedRequest,
    required R Function() badRequest,
    required R Function(String reason) notFound,
    required R Function() methodNotAllowed,
    required R Function() notAcceptable,
    required R Function() requestTimeout,
    required R Function() sendTimeout,
    required R Function() conflict,
    required R Function() internalServerError,
    required R Function() notImplemented,
    required R Function() serviceUnavailable,
    required R Function() noInternetConnection,
    required R Function() formatException,
    required R Function() unableToProcess,
    required R Function() defaultError,
    required R Function() unexpectedError,
  }) => defaultError();
}

class UnexpectedError extends NetworkExceptions {
  const UnexpectedError();

  @override
  R when<R>({
    required R Function() requestCancelled,
    required R Function() unauthorisedRequest,
    required R Function() badRequest,
    required R Function(String reason) notFound,
    required R Function() methodNotAllowed,
    required R Function() notAcceptable,
    required R Function() requestTimeout,
    required R Function() sendTimeout,
    required R Function() conflict,
    required R Function() internalServerError,
    required R Function() notImplemented,
    required R Function() serviceUnavailable,
    required R Function() noInternetConnection,
    required R Function() formatException,
    required R Function() unableToProcess,
    required R Function() defaultError,
    required R Function() unexpectedError,
  }) => unexpectedError();
}