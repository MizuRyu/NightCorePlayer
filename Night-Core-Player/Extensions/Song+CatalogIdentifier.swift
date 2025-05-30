import Foundation
import MusicKit

extension Song {
    enum PersistenceError: Error {
        case encodingFailed
        case decodingFailed
    }
    
    /// 永続化用の識別子を取得
    /// - playParameters が無ければ id.rawValue
    /// - JSON 化→辞書化して catalogId キー値を探す
    func persistenceID() throws -> String {
        let raw = id.rawValue
        // playParameters がなければそのまま
        guard let params = playParameters else {
            return raw
        }
        let data: Data
        do {
            data = try JSONEncoder().encode(params)
        } catch {
            throw PersistenceError.encodingFailed
        }
        let jsonObj: Any
        do {
            jsonObj = try JSONSerialization.jsonObject(with: data, options: [])
        } catch {
            throw PersistenceError.decodingFailed
        }
        guard let dict = jsonObj as? [String: Any],
              let catalogID = dict["catalogId"] as? String
        else {
            return raw
        }
        return catalogID
    }
}
