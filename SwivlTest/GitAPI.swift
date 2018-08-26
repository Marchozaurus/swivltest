//
//  GitAPI.swift
//  SwivlTest
//
//  Created by Oleksandr Marchenko on 8/25/18.
//  Copyright © 2018 Oleksandr Marchenko. All rights reserved.
//

import Foundation
import RxSwift
import HTTPStatusCodes

//{
//    "login": "octocat",
//    "id": 1,
//    "node_id": "MDQ6VXNlcjE=",
//    "avatar_url": "https://github.com/images/error/octocat_happy.gif",
//    "gravatar_id": "",
//    "url": "https://api.github.com/users/octocat",
//    "html_url": "https://github.com/octocat",
//    "followers_url": "https://api.github.com/users/octocat/followers",
//    "following_url": "https://api.github.com/users/octocat/following{/other_user}",
//    "gists_url": "https://api.github.com/users/octocat/gists{/gist_id}",
//    "starred_url": "https://api.github.com/users/octocat/starred{/owner}{/repo}",
//    "subscriptions_url": "https://api.github.com/users/octocat/subscriptions",
//    "organizations_url": "https://api.github.com/users/octocat/orgs",
//    "repos_url": "https://api.github.com/users/octocat/repos",
//    "events_url": "https://api.github.com/users/octocat/events{/privacy}",
//    "received_events_url": "https://api.github.com/users/octocat/received_events",
//    "type": "User",
//    "site_admin": false
//}

class GitUser: Decodable {
    private enum CodingKeys: String, CodingKey {
        case login
        case htmlURL = "html_url"
        case avatarURL = "avatar_url"
        case followersURL = "followers_url"
    }

    let login: String
    let htmlURL: URL
    let avatarURL: URL
    let followersURL: URL
}

typealias GitUsersPage = (users: [GitUser], nextPageUrl: URL?)

class GitAPI {
    private static let usersURL = URL(string: "https://api.github.com/users")!

    enum Error: Swift.Error {
        case networkError(underlyingError: Swift.Error)
        case serverError(statusCode: HTTPStatusCode, response: String)
        case parsingError(underlyingError: Swift.Error)
        case unknownError
    }

    static func getUsers(url: URL? = nil) -> Single<GitUsersPage> {
        let url = url ?? GitAPI.usersURL
        print("Retrieving \(url))")
        return Single.create { observer in
            let task = URLSession.shared.dataTask(with: url) { data, response, error in
                DispatchQueue.main.async {
                    if let error = error {
                        observer(.error(Error.networkError(underlyingError: error)))
                        return
                    }

                    guard let httpResponse = response as? HTTPURLResponse else { fatalError("Should never happen") }

                    guard let data = data else {
                        observer(.error(Error.serverError(statusCode: httpResponse.statusCodeEnum, response: "Empty response")))
                        return
                    }

                    guard httpResponse.statusCodeEnum.isSuccess else {
                        let responseString = String(data: data, encoding: .utf8) ?? "Empty response"

                        observer(.error(Error.serverError(statusCode: httpResponse.statusCodeEnum, response: responseString)))
                        return
                    }

                    do {
                        let decoder = JSONDecoder()
                        let users = try decoder.decode([GitUser].self, from: data)
                        let result = GitUsersPage(users: users, nextPageUrl: httpResponse.linkForNext())
                        observer(.success(result))
                    } catch {
                        observer(.error(Error.parsingError(underlyingError: error)))
                    }
                }
            }

            task.resume()

            return Disposables.create()
        }
    }
}

extension HTTPURLResponse {
    func linkForNext() -> URL? {
        guard let linkHeader = allHeaderFields["Link"] as? String else {
            return nil
        }

        let pattern = "<([^<>]*)>; rel=\"next\""

        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { fatalError("Invalid regex pattern") }

        guard let match = regex.firstMatch(in: linkHeader, range: NSRange(location: 0, length: linkHeader.count)) else {
            return nil
        }

        guard match.numberOfRanges == 2 else {
            return nil
        }

        guard let range = Range(match.range(at: 1), in: linkHeader) else {
            return nil
        }

        guard let url = URL(string: String(linkHeader[range])) else {
            return nil
        }

        return url
    }
}
