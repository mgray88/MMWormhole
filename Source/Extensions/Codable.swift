//
//  Codable.swift
//  MMWormhole
//
//  Created by Maris Lagzdins on 18/05/2020.
//

import Foundation

extension MMWormhole {
    public func passMessageObject<T: Encodable>(_ messageObject: T, identifier: String, encoder: JSONEncoder = JSONEncoder()) {
        guard let data = try? encoder.encode(messageObject) else {
            return
        }

        self.passMessageObject(data as NSCoding, identifier: identifier)
    }

    public func listenForMessage<T: Decodable>(withIdentifier identifier: String, decoder: JSONDecoder = JSONDecoder(), listener: @escaping (T) -> Void) {
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
}
