//
//  Codable.swift
//  MMWormhole
//
//  Created by Maris Lagzdins on 18/05/2020.
//

import Foundation
import MMWormhole

public protocol Wormholable: Codable {
    static var identifier: String { get }
}

extension Wormhole {
    public func passMessageObject<T: Encodable>(
        _ messageObject: T,
        identifier: String,
        encoder: JSONEncoder = JSONEncoder()
    ) {
        guard let data = try? encoder.encode(messageObject) else {
            return
        }

        self.passMessageObject(data as NSCoding, identifier: identifier)
    }

    public func passMessageObject<T: Wormholable>(
        _ object: T,
        encoder: JSONEncoder = JSONEncoder()
    ) {
        self.passMessageObject(object, identifier: T.identifier, encoder: encoder)
    }

    public func listenForMessage<T: Decodable>(
        withIdentifier identifier: String,
        decoder: JSONDecoder = JSONDecoder(),
        listener: @escaping (T) -> Void
    ) {
        listenForMessage(withIdentifier: identifier) { anyMessage in
            guard let data = anyMessage as? Data else {
                return
            }

            guard let message = try? decoder.decode(T.self, from: data) else {
                return
            }

            listener(message)
        }
    }

    public func listenForMessage<T: Wormholable>(
        ofType type: T.Type,
        decoder: JSONDecoder = JSONDecoder(),
        listener: @escaping (T) -> Void
    ) {
        listenForMessage(withIdentifier: T.identifier, decoder: decoder, listener: listener)
    }
}

extension QueuedWormhole {
    public func listenForMessages<T: Decodable>(
        identifier: String,
        decoder: JSONDecoder = JSONDecoder(),
        listener: @escaping ([T]) -> Void
    ) {
        listenForMessages(identifier: identifier) { anyMessages in
            let messages = anyMessages?.compactMap { any -> T? in
                guard let data = any as? Data else { return nil }
                return try? decoder.decode(T.self, from: data)
            }
            if let messages = messages {
                listener(messages)
            }
        }
    }

    public func listenForMessages<T: Wormholable>(
        ofType type: T.Type,
        decoder: JSONDecoder = JSONDecoder(),
        listener: @escaping ([T]) -> Void
    ) {
        listenForMessages(identifier: T.identifier, decoder: decoder, listener: listener)
    }
}
