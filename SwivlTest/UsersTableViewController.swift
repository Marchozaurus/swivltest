//
//  UsersTableViewController.swift
//  SwivlTest
//
//  Created by Oleksandr Marchenko on 8/25/18.
//  Copyright © 2018 Oleksandr Marchenko. All rights reserved.
//

import UIKit
import RxSwift
import Kingfisher

class UsersTableViewController: UITableViewController {
    private struct Constants {
        static let usersCellIdentifier = "usersCell"
    }

    @IBOutlet private var nextPageActivityIndicator: UIActivityIndicatorView!

    var firstPageUrl: URL?
    private var nextPageUrl: URL? {
        didSet {
            updateNextPageActivityIndicator()
        }
    }

    private func updateNextPageActivityIndicator() {
        guard loadError == nil else {
            nextPageActivityIndicator.stopAnimating()
            return
        }

        guard nextPageUrl != nil else {
            nextPageActivityIndicator.stopAnimating()
            return
        }

        nextPageActivityIndicator.startAnimating()
    }

    private var loadError: Error? {
        didSet {
            tableView.tableHeaderView = loadError.flatMap { _ in
                let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: "headerView")
                headerView?.textLabel?.text = NSLocalizedString("    Loading error", comment: "")
                headerView?.frame.size.height = 35.0
                return headerView
            }

            updateNextPageActivityIndicator()
        }
    }

    private var users = [GitUser]() {
        didSet {
            tableView.reloadData()
        }
    }

    private var usersRequestDisposeBag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UITableViewHeaderFooterView.self, forHeaderFooterViewReuseIdentifier: "headerView")
        
        getUsers(url: firstPageUrl)
    }

    @IBAction func refresh() {
        nextPageUrl = nil
        getUsers(url: firstPageUrl)
    }

    private func getUsers(url: URL?, append: Bool = false) {
        usersRequestDisposeBag = DisposeBag()

        GitAPI.getUsers(url: url).subscribe { [weak self] event in
            self?.refreshControl?.endRefreshing()

            switch event {
            case .error(let error):
                self?.loadError = error
            case .success(let page):
                self?.loadError = nil
                if append {
                    self?.users.append(contentsOf: page.users)
                } else {
                    self?.users = page.users
                }
                self?.nextPageUrl = page.nextPageUrl
            }
        }.disposed(by: usersRequestDisposeBag)
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return users.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Constants.usersCellIdentifier, for: indexPath)

        let user = users[indexPath.row]
        cell.textLabel?.text = user.login
        cell.detailTextLabel?.text = user.htmlURL.absoluteString
        let processor = ResizingImageProcessor(referenceSize: CGSize(width: 100.0, height: 100.0))
        cell.imageView?.kf.setImage(with: user.avatarURL, options: [.processor(processor)]) { _,_,_,_ in
            cell.setNeedsLayout()
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if indexPath.row == users.count - 1, nextPageUrl != nil {
            getUsers(url: nextPageUrl, append: true)
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let controller = storyboard?.instantiateViewController(withIdentifier: "UsersTableViewController") as? UsersTableViewController else {
            return
        }

        let user = users[indexPath.row]
        controller.title = user.login
        controller.firstPageUrl = user.followersURL
        show(controller, sender: self)
    }
}
