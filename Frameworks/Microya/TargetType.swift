//
//  Created by Cihat Gündüz on 14.02.19.
//  Copyright © 2019 Flinesoft. All rights reserved.
//

//  Created by Cihat Gündüz on 14.01.19.

import Foundation

public enum MicroyaError: Error {
    case noResponseReceived
    case noDataReceived
    case responseDataConversionFailed(type: String, error: Error)
    case unexpectedStatusCode(Int)
    case unknownError(Error)
}

public protocol TargetType: class {
    var decoder: JSONDecoder { get }
    var encoder: JSONEncoder { get }

    var baseUrl: URL { get }
    var headers: [String: String] { get }
    var path: String { get }
    var method: Method { get }
    var queryParameters: [(key: String, value: String)] { get }
    var bodyData: Data? { get }
}

// MARK: - Extensions
extension TargetType {
    /// Launch a request by using non-void return method
    public func request<ResultType: Decodable>(type: ResultType.Type) -> Result<ResultType, MicroyaError> {
        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()

        var result: Result<ResultType, MicroyaError>?

        var request = URLRequest(url: requestUrl())
        for (field, value) in headers {
            request.setValue(value, forHTTPHeaderField: field)
        }

        if let bodyData = bodyData {
            request.httpBody = bodyData
        }

        request.httpMethod = method.rawValue

        let dataTask = URLSession.shared.dataTask(with: request) { data, urlResponse, error in
            result = {
                guard error == nil else { return .failure(.unknownError(error!)) }
                guard let httpUrlResponse = urlResponse as? HTTPURLResponse else {
                    return .failure(.noResponseReceived)
                }

                switch httpUrlResponse.statusCode {
                case 200 ..< 300:
                    guard let data = data else { return .failure(.noDataReceived) }
                    do {
                        let typedResult = try self.decoder.decode(type, from: data)
                        return .success(typedResult)
                    } catch {
                        return .failure(.responseDataConversionFailed(type: String(describing: type), error: error))
                    }

                case 400 ..< 500:
                    return .failure(.unexpectedStatusCode(httpUrlResponse.statusCode))

                case 500 ..< 600:
                    return .failure(.unexpectedStatusCode(httpUrlResponse.statusCode))

                default:
                    return .failure(.unexpectedStatusCode(httpUrlResponse.statusCode))
                }
            }()

            dispatchGroup.leave()
        }

        dataTask.resume()
        dispatchGroup.wait()

        return result!
    }
}

extension TargetType /* Closure usage request */ {
    /// Launch a request by using closure method
    public func request<ResultType: Decodable>(type: ResultType.Type, closure: @escaping ((Result<ResultType, MicroyaError>) -> Void)) {
        var request = URLRequest(url: requestUrl())
        for (field, value) in headers {
            request.setValue(value, forHTTPHeaderField: field)
        }

        if let bodyData = bodyData {
            request.httpBody = bodyData
        }

        request.httpMethod = method.rawValue

        let task = URLSession.shared.dataTask(with: request) { [weak self] data, urlResponse, error in
            guard let this = self else {
                // nothing to do here, mem was freed before we handled this
                return
            }

            guard error == nil else {
                if let unwrapped = error {
                    closure(.failure(.unknownError(unwrapped)))
                }
                return
            }
            guard let httpUrlResponse = urlResponse as? HTTPURLResponse else {
                closure(.failure(.noResponseReceived))
                return
            }

            switch httpUrlResponse.statusCode {
            case 200 ..< 300:
                guard let data = data else {
                    closure(.failure(.noDataReceived))
                    return
                }
                do {
                    let typedResult = try this.decoder.decode(type, from: data)
                    closure(.success(typedResult))
                } catch {
                    closure(.failure(.responseDataConversionFailed(type: String(describing: type), error: error)))
                    return
                }

            case 400 ..< 500:
                closure(.failure(.unexpectedStatusCode(httpUrlResponse.statusCode)))
                return

            case 500 ..< 600:
                closure(.failure(.unexpectedStatusCode(httpUrlResponse.statusCode)))
                return

            default:
                closure(.failure(.unexpectedStatusCode(httpUrlResponse.statusCode)))
                return
            }
        }
        task.resume()
    }
}

extension TargetType {
    private func requestUrl() -> URL {
        var urlComponents = URLComponents(url: baseUrl.appendingPathComponent(path), resolvingAgainstBaseURL: false)!

        urlComponents.queryItems = []
        for (key, value) in queryParameters {
            urlComponents.queryItems?.append(URLQueryItem(name: key, value: value))
        }

        return urlComponents.url!
    }
}
