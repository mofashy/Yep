//
//  ProfileViewController.swift
//  Yep
//
//  Created by NIX on 15/3/16.
//  Copyright (c) 2015年 Catch Inc. All rights reserved.
//

import UIKit
import RealmSwift

let profileAvatarAspectRatio: CGFloat = 12.0 / 16.0

enum SocialAccount: String, Printable {
    case Dribbble = "dribbble"
    case Github = "github"
    case Instagram = "instagram"
    case Behance = "behance"
    
    var description: String {
        
        switch self {
        case .Dribbble:
            return "Dribbble"
        case .Github:
            return "Github"
        case .Behance:
            return "Behance"
        case .Instagram:
            return "Instagram"
        }
        
    }
    
    var tintColor: UIColor {
        
        switch self {
        case .Dribbble:
            return UIColor(red:0.91, green:0.28, blue:0.5, alpha:1)
        case .Github:
            return UIColor.blackColor()
        case .Behance:
            return UIColor(red:0, green:0.46, blue:1, alpha:1)
        case .Instagram:
            return UIColor(red:0.15, green:0.36, blue:0.54, alpha:1)
        }
    }
    
    var iconName: String {
        
        switch self {
        case .Dribbble:
            return "icon_dribbble"
        case .Github:
            return "icon_github"
        case .Behance:
            return "icon_behance"
        case .Instagram:
            return "icon_instagram"
        }
    }
    
    var authURL: NSURL {
        
        switch self {
        case .Dribbble:
            return NSURL(string: "\(baseURL.absoluteString!)/auth/dribbble")!
        case .Github:
            return NSURL(string: "\(baseURL.absoluteString!)/auth/github")!
        case .Behance:
            return NSURL(string: "\(baseURL.absoluteString!)/auth/behance")!
        case .Instagram:
            return NSURL(string: "\(baseURL.absoluteString!)/auth/instagram")!
        }
    }
}

enum ProfileUser {
    case DiscoveredUserType(DiscoveredUser)
    case UserType(User)

    var isMe: Bool {

        let userID: String

        switch self {

        case .DiscoveredUserType(let discoveredUser):
            userID = discoveredUser.id

        case .UserType(let user):
            userID = user.userID
        }

        if let myUserID = YepUserDefaults.userID.value {
            return (userID == myUserID)
        }

        return false
    }

    func enabledSocialAccount(socialAccount: SocialAccount) -> Bool {
        var accountEnabled = false

        let providerName = socialAccount.rawValue

        switch self {

        case .DiscoveredUserType(let discoveredUser):
            for provider in discoveredUser.socialAccountProviders {
                if (provider.name == providerName) && provider.enabled {

                    accountEnabled = true

                    break
                }
            }

        case .UserType(let user):
            for provider in user.socialAccountProviders {
                if (provider.name == providerName) && provider.enabled {

                    accountEnabled = true

                    break
                }
            }
        }

        return accountEnabled
    }
}

class ProfileViewController: UIViewController {

    var isFromConversation = false

    var profileUser: ProfileUser?
    var profileUserIsMe = true {
        didSet {
            if !profileUserIsMe {

                let moreBarButtonItem = UIBarButtonItem(image: UIImage(named: "icon_more"), style: UIBarButtonItemStyle.Plain, target: self, action: "moreAction")

                customNavigationItem.rightBarButtonItem = moreBarButtonItem


                if isFromConversation {
                    sayHiView.hidden = true

                } else {
                    sayHiView.sayHiAction = {
                        self.sayHi()
                    }

                    profileCollectionView.contentInset.bottom = sayHiView.bounds.height
                }

            } else {
                sayHiView.hidden = true

                let settingsBarButtonItem = UIBarButtonItem(image: UIImage(named: "icon_settings"), style: UIBarButtonItemStyle.Plain, target: self, action: "showSettings")

                customNavigationItem.rightBarButtonItem = settingsBarButtonItem
            }
        }
    }

    @IBOutlet weak var topShadowImageView: UIImageView!
    @IBOutlet weak var profileCollectionView: UICollectionView!

    @IBOutlet weak var sayHiView: SayHiView!

    var customNavigationBar: UINavigationBar!

    let skillCellIdentifier = "SkillCell"
    let headerCellIdentifier = "ProfileHeaderCell"
    let footerCellIdentifier = "ProfileFooterCell"
    let sectionHeaderIdentifier = "ProfileSectionHeaderReusableView"
    let sectionFooterIdentifier = "ProfileSectionFooterReusableView"
    let separationLineCellIdentifier = "ProfileSeparationLineCell"
    let socialAccountCellIdentifier = "ProfileSocialAccountCell"
    let socialAccountImagesCellIdentifier = "ProfileSocialAccountImagesCell"
    let socialAccountGithubCellIdentifier = "ProfileSocialAccountGithubCell"

    lazy var collectionViewWidth: CGFloat = {
        return CGRectGetWidth(self.profileCollectionView.bounds)
        }()
    lazy var sectionLeftEdgeInset: CGFloat = { return YepConfig.Profile.leftEdgeInset }()
    lazy var sectionRightEdgeInset: CGFloat = { return YepConfig.Profile.rightEdgeInset }()
    lazy var sectionBottomEdgeInset: CGFloat = { return 0 }()

    lazy var introductionText: String = {

        var introduction: String?

        if let profileUser = self.profileUser {
            switch profileUser {
                
            case .DiscoveredUserType(let discoveredUser):
                if let _introduction = discoveredUser.introduction {
                    if !_introduction.isEmpty {
                        introduction = _introduction
                    }
                }

            case .UserType(let user):

                if !user.introduction.isEmpty {
                    introduction = user.introduction
                }

                if user.friendState == UserFriendState.Me.rawValue {
                    YepUserDefaults.introduction.bindListener(Listener.Introduction) { [weak self] introduction in
                        if let introduction = introduction {
                            self?.introductionText = introduction
                            self?.updateProfileCollectionView()
                        }
                    }
                }
            }
        }

        return introduction ?? NSLocalizedString("No Introduction yet.", comment: "")
        }()

    var masterSkills = [Skill]() {
        didSet {
            let realm = Realm()

            if let
                myUserID = YepUserDefaults.userID.value,
                me = userWithUserID(myUserID, inRealm: realm) {
                    realm.write {
                        me.masterSkills.removeAll()
                        let userSkills = userSkillsFromSkills(self.masterSkills, inRealm: realm)
                        me.masterSkills.extend(userSkills)
                    }
            }
        }
    }
    var learningSkills = [Skill]() {
        didSet {
            let realm = Realm()

            if let
                myUserID = YepUserDefaults.userID.value,
                me = userWithUserID(myUserID, inRealm: realm) {
                    realm.write {
                        me.learningSkills.removeAll()
                        let userSkills = userSkillsFromSkills(self.learningSkills, inRealm: realm)
                        me.learningSkills.extend(userSkills)
                    }
            }
        }
    }


    var dribbbleWork: DribbbleWork?
    var instagramWork: InstagramWork?
    var githubWork: GithubWork?


    let skillTextAttributes = [NSFontAttributeName: UIFont.skillTextFont()]

    var footerCellHeight: CGFloat {
        get {
            let attributes = [NSFontAttributeName: YepConfig.Profile.introductionLabelFont]
            let labelWidth = self.collectionViewWidth - (YepConfig.Profile.leftEdgeInset + YepConfig.Profile.rightEdgeInset)
            let rect = self.introductionText.boundingRectWithSize(CGSize(width: labelWidth, height: CGFloat(FLT_MAX)), options: .UsesLineFragmentOrigin | .UsesFontLeading, attributes:attributes, context:nil)
            return ceil(rect.height) + 4
        }
    }
    
    var customNavigationItem: UINavigationItem = UINavigationItem(title: "Details")


    struct Listener {
        static let Nickname = "ProfileViewController.Title"
        static let Introduction = "Profile.introductionText"
    }

    // MARK: Life cycle

    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)

        YepUserDefaults.nickname.removeListenerWithName(Listener.Nickname)
        YepUserDefaults.introduction.removeListenerWithName(Listener.Introduction)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        NSNotificationCenter.defaultCenter().addObserver(self, selector: "cleanForLogout", name: EditProfileViewController.Notification.Logout, object: nil)

        if profileUser == nil {
            if let
                myUserID = YepUserDefaults.userID.value,
                me = userWithUserID(myUserID, inRealm: Realm()) {
                    profileUser = ProfileUser.UserType(me)

                    masterSkills = skillsFromUserSkillList(me.masterSkills)
                    learningSkills = skillsFromUserSkillList(me.learningSkills)
            }
        }

        profileUserIsMe = profileUser?.isMe ?? false


        if let profileLayout = profileCollectionView.collectionViewLayout as? ProfileLayout {

            profileLayout.scrollUpAction = { progress in

                let indexPath = NSIndexPath(forItem: 0, inSection: ProfileSection.Header.rawValue)
                
                if let coverCell = self.profileCollectionView.cellForItemAtIndexPath(indexPath) as? ProfileHeaderCell {

                    let beginChangePercentage: CGFloat = 1 - 64 / self.collectionViewWidth * profileAvatarAspectRatio
                    let normalizedProgressForChange: CGFloat = (progress - beginChangePercentage) / (1 - beginChangePercentage)

                    coverCell.avatarBlurImageView.alpha = progress < beginChangePercentage ? 0 : normalizedProgressForChange

                    self.topShadowImageView.alpha = progress < beginChangePercentage ? 1 : 1 - normalizedProgressForChange

                    coverCell.locationLabel.alpha = progress < 0.5 ? 1 : 1 - min(1, (progress - 0.5) * 2 * 2) // 特别对待，在后半程的前半段即完成 alpha -> 0
                }
            }
        }

        profileCollectionView.registerNib(UINib(nibName: skillCellIdentifier, bundle: nil), forCellWithReuseIdentifier: skillCellIdentifier)
        profileCollectionView.registerNib(UINib(nibName: headerCellIdentifier, bundle: nil), forCellWithReuseIdentifier: headerCellIdentifier)
        profileCollectionView.registerNib(UINib(nibName: footerCellIdentifier, bundle: nil), forCellWithReuseIdentifier: footerCellIdentifier)
        profileCollectionView.registerNib(UINib(nibName: separationLineCellIdentifier, bundle: nil), forCellWithReuseIdentifier: separationLineCellIdentifier)
        profileCollectionView.registerNib(UINib(nibName: socialAccountCellIdentifier, bundle: nil), forCellWithReuseIdentifier: socialAccountCellIdentifier)
        profileCollectionView.registerNib(UINib(nibName: socialAccountImagesCellIdentifier, bundle: nil), forCellWithReuseIdentifier: socialAccountImagesCellIdentifier)
        profileCollectionView.registerNib(UINib(nibName: socialAccountGithubCellIdentifier, bundle: nil), forCellWithReuseIdentifier: socialAccountGithubCellIdentifier)
        profileCollectionView.registerNib(UINib(nibName: sectionHeaderIdentifier, bundle: nil), forSupplementaryViewOfKind: UICollectionElementKindSectionHeader, withReuseIdentifier: sectionHeaderIdentifier)
        profileCollectionView.registerClass(UICollectionReusableView.self, forSupplementaryViewOfKind: UICollectionElementKindSectionFooter, withReuseIdentifier: sectionFooterIdentifier)

        profileCollectionView.alwaysBounceVertical = true
        
        automaticallyAdjustsScrollViewInsets = false
        
        
        customNavigationBar = UINavigationBar(frame: CGRectMake(0, 0, CGRectGetWidth(self.view.bounds), 64.0))
        customNavigationBar.alpha = 0
        customNavigationBar.setItems([customNavigationItem], animated: false)
        view.addSubview(customNavigationBar)
        
        customNavigationBar.backgroundColor = UIColor.clearColor()
        customNavigationBar.translucent = true
        customNavigationBar.shadowImage = UIImage()
        customNavigationBar.barStyle = UIBarStyle.BlackTranslucent
        customNavigationBar.setBackgroundImage(UIImage(), forBarMetrics: UIBarMetrics.Default)
        
        let textAttributes = [
            NSForegroundColorAttributeName: UIColor.whiteColor(),
            NSFontAttributeName: UIFont.navigationBarTitleFont()
        ]
        
        customNavigationBar.titleTextAttributes = textAttributes
        customNavigationBar.tintColor = UIColor.whiteColor()
        
        
        //Make sure when pan edge screen collectionview not scroll
        if let gestures = navigationController?.view.gestureRecognizers {
            for recognizer in gestures
            {
                if recognizer.isKindOfClass(UIScreenEdgePanGestureRecognizer)
                {
                    profileCollectionView.panGestureRecognizer.requireGestureRecognizerToFail(recognizer as! UIScreenEdgePanGestureRecognizer)
                    println("Require UIScreenEdgePanGestureRecognizer to failed")
                    break
                }
            }
        }

        if let tabBarController = tabBarController {
            profileCollectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: CGRectGetHeight(tabBarController.tabBar.bounds), right: 0)
        }

        if let profileUser = profileUser {
            switch profileUser {
            case .DiscoveredUserType(let discoveredUser):
                customNavigationItem.title = discoveredUser.nickname
            case .UserType(let user):
                customNavigationItem.title = user.nickname

                if user.friendState == UserFriendState.Me.rawValue {
                    YepUserDefaults.nickname.bindListener(Listener.Nickname) { [weak self] nickname in
                        self?.customNavigationItem.title = nickname
                    }
                }
            }
        }

    }
    
    func showSettings() {
        self.performSegueWithIdentifier("showSettings", sender: self)
    }
    
    override func viewWillAppear(animated: Bool) {
        
        super.viewWillAppear(animated)
        
        self.navigationController?.setNavigationBarHidden(true, animated: true)
    
        customNavigationBar.alpha = 1.0
        
        self.setNeedsStatusBarAppearanceUpdate()
    }

    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return UIStatusBarStyle.LightContent
    }

    // MARK: Navigation
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        
        if segue.identifier == "showConversation" {
            let vc = segue.destinationViewController as! ConversationViewController
            vc.conversation = sender as! Conversation
            
        } else if segue.identifier == "showSkillHome" {
            if let skillInfo = sender as? [String: String] {
                let vc = segue.destinationViewController as! SkillHomeViewController
                vc.hidesBottomBarWhenPushed = true

                vc.skillID = skillInfo["skillID"]
                vc.skillLocalName = skillInfo["skillLocalName"]
            }

        } else if segue.identifier == "presentOAuth" {
            if let providerName = sender as? String {
                let nvc = segue.destinationViewController as! UINavigationController
                let vc = nvc.topViewController as! OAuthViewController
                vc.socialAccount = SocialAccount(rawValue: providerName)

                vc.afterOAuthAction = { [weak self] socialAccount in
                    // 更新自己的 provider enabled 状态
                    let providerName = socialAccount.rawValue

                    let realm = Realm()

                    if let
                        myUserID = YepUserDefaults.userID.value,
                        me = userWithUserID(myUserID, inRealm: realm) {

                            for socialAccountProvider in me.socialAccountProviders {
                                if socialAccountProvider.name == providerName {
                                    realm.write {
                                        socialAccountProvider.enabled = true
                                    }

                                    break
                                }
                            }

                            dispatch_async(dispatch_get_main_queue()) {
                                self?.updateProfileCollectionView()
                            }

                    }
                }
            }

        } else if segue.identifier == "showSocialWorkGithub" {
            if let providerName = sender as? String {
                let vc = segue.destinationViewController as! SocialWorkGithubViewController
                vc.socialAccount = SocialAccount(rawValue: providerName)
                vc.profileUser = profileUser
                vc.githubWork = githubWork

                vc.afterGetGithubWork = { githubWork in
                    self.githubWork = githubWork
                }
            }

        } else if segue.identifier == "showSocialWorkDribbble" {
            if let providerName = sender as? String {
                let vc = segue.destinationViewController as! SocialWorkDribbbleViewController
                vc.socialAccount = SocialAccount(rawValue: providerName)
                vc.profileUser = profileUser
                vc.dribbbleWork = dribbbleWork

                vc.afterGetDribbbleWork = { dribbbleWork in
                    self.dribbbleWork = dribbbleWork
                }
            }

        } else if segue.identifier == "showSocialWorkInstagram" {
            if let providerName = sender as? String {
                let vc = segue.destinationViewController as! SocialWorkInstagramViewController
                vc.socialAccount = SocialAccount(rawValue: providerName)
                vc.profileUser = profileUser
                vc.instagramWork = instagramWork

                vc.afterGetInstagramWork = { instagramWork in
                    self.instagramWork = instagramWork
                }
            }
        }
    }

    // MARK: Actions

    func setBackButtonWithTitle() {
        let backBarButtonItem = UIBarButtonItem(image: UIImage(named: "icon_back"), style: UIBarButtonItemStyle.Plain, target: self, action: "popBack")
        backBarButtonItem.tintColor = UIColor.whiteColor()

        customNavigationItem.leftBarButtonItem = backBarButtonItem
    }

    func popBack() {
        navigationController?.popViewControllerAnimated(true)
    }

    func cleanForLogout() {
        profileUser = nil
    }

    func updateProfileCollectionView() {
        dispatch_async(dispatch_get_main_queue()) {
            self.profileCollectionView.collectionViewLayout.invalidateLayout()
            self.profileCollectionView.reloadData()
            self.profileCollectionView.layoutIfNeeded()
        }
    }

    func sayHi() {

        if let profileUser = profileUser {

            let realm = Realm()

            switch profileUser {

            case .DiscoveredUserType(let discoveredUser):
                var stranger = userWithUserID(discoveredUser.id, inRealm: realm)

                if stranger == nil {
                    let newUser = User()

                    newUser.userID = discoveredUser.id

                    newUser.friendState = UserFriendState.Stranger.rawValue

                    realm.beginWrite()
                    realm.add(newUser)
                    realm.commitWrite()

                    stranger = newUser
                }

                if let user = stranger {

                    realm.beginWrite()

                    // 更新用户信息

                    user.lastSignInUnixTime = discoveredUser.lastSignInUnixTime

                    user.nickname = discoveredUser.nickname

                    if let introduction = discoveredUser.introduction {
                        user.introduction = introduction
                    }
                    
                    user.avatarURLString = discoveredUser.avatarURLString

                    // 更新技能

                    user.learningSkills.removeAll()
                    let learningUserSkills = userSkillsFromSkills(discoveredUser.learningSkills, inRealm: realm)
                    user.learningSkills.extend(learningUserSkills)

                    user.masterSkills.removeAll()
                    let masterUserSkills = userSkillsFromSkills(discoveredUser.masterSkills, inRealm: realm)
                    user.masterSkills.extend(masterUserSkills)

                    // 更新 Social Account Provider

                    user.socialAccountProviders.removeAll()
                    let socialAccountProviders = userSocialAccountProvidersFromSocialAccountProviders(discoveredUser.socialAccountProviders)
                    user.socialAccountProviders.extend(socialAccountProviders)

                    realm.commitWrite()


                    if user.conversation == nil {
                        let newConversation = Conversation()

                        newConversation.type = ConversationType.OneToOne.rawValue
                        newConversation.withFriend = user

                        realm.beginWrite()
                        realm.add(newConversation)
                        realm.commitWrite()
                    }

                    if let conversation = user.conversation {
                        performSegueWithIdentifier("showConversation", sender: conversation)
                        
                        NSNotificationCenter.defaultCenter().postNotificationName(YepNewMessagesReceivedNotification, object: nil)
                    }
                }

            case .UserType(let user):

                if user.friendState != UserFriendState.Me.rawValue {

                    if user.conversation == nil {
                        let newConversation = Conversation()

                        newConversation.type = ConversationType.OneToOne.rawValue
                        newConversation.withFriend = user

                        realm.beginWrite()
                        realm.add(newConversation)
                        realm.commitWrite()
                    }

                    if let conversation = user.conversation {
                        performSegueWithIdentifier("showConversation", sender: conversation)

                        NSNotificationCenter.defaultCenter().postNotificationName(YepNewMessagesReceivedNotification, object: nil)
                    }
                }
            }
        }
    }

    func moreAction() {

        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .ActionSheet)

        let toggleDisturbAction: UIAlertAction = UIAlertAction(title: NSLocalizedString("Do not disturb", comment: ""), style: .Default) { action -> Void in
            // TODO: toggleDisturbAction
        }
        alertController.addAction(toggleDisturbAction)

        let reportAction: UIAlertAction = UIAlertAction(title: NSLocalizedString("Report", comment: ""), style: .Default) { action -> Void in

            let reportWithReason: ReportReason -> Void = { reason in

                if let profileUser = self.profileUser {

                    reportProfileUser(profileUser, forReason: reason, failureHandler: { (reason, errorMessage) in
                        defaultFailureHandler(reason, errorMessage)

                        if let errorMessage = errorMessage {
                            dispatch_async(dispatch_get_main_queue()) {
                                YepAlert.alertSorry(message: errorMessage, inViewController: self)
                            }
                        }

                    }, completion: { success in
                        dispatch_async(dispatch_get_main_queue()) {
                            YepAlert.alert(title: NSLocalizedString("Success", comment: ""), message: NSLocalizedString("Report recorded!", comment: ""), dismissTitle: NSLocalizedString("OK", comment: ""), inViewController: self, withDismissAction: nil)
                        }
                    })
                }
            }

            let reportAlertController = UIAlertController(title: NSLocalizedString("Report Reason", comment: ""), message: nil, preferredStyle: .ActionSheet)

            let pornoReasonAction: UIAlertAction = UIAlertAction(title: ReportReason.Porno.description, style: .Default) { action -> Void in
                reportWithReason(.Porno)
            }
            reportAlertController.addAction(pornoReasonAction)

            let advertisingReasonAction: UIAlertAction = UIAlertAction(title: ReportReason.Advertising.description, style: .Default) { action -> Void in
                reportWithReason(.Advertising)
            }
            reportAlertController.addAction(advertisingReasonAction)

            let scamsReasonAction: UIAlertAction = UIAlertAction(title: ReportReason.Scams.description, style: .Default) { action -> Void in
                reportWithReason(.Scams)
            }
            reportAlertController.addAction(scamsReasonAction)

            let otherReasonAction: UIAlertAction = UIAlertAction(title: ReportReason.Other("").description, style: .Default) { action -> Void in
                YepAlert.textInput(title: NSLocalizedString("Other Reason", comment: ""), placeholder: nil, oldText: nil, confirmTitle: NSLocalizedString("OK", comment: ""), cancelTitle: NSLocalizedString("Cancel", comment: ""), inViewController: self, withConfirmAction: { text in
                    reportWithReason(.Other(text))
                }, cancelAction: nil)
            }
            reportAlertController.addAction(otherReasonAction)

            let cancelAction: UIAlertAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .Cancel) { action -> Void in
                self.dismissViewControllerAnimated(true, completion: nil)
            }
            reportAlertController.addAction(cancelAction)

            self.presentViewController(reportAlertController, animated: true, completion: nil)
        }
        alertController.addAction(reportAction)

        let blockAction: UIAlertAction = UIAlertAction(title: NSLocalizedString("Block", comment: ""), style: .Destructive) { action -> Void in
            // TODO: blockAction
        }
        alertController.addAction(blockAction)

        let cancelAction: UIAlertAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .Cancel) { action -> Void in
            self.dismissViewControllerAnimated(true, completion: nil)
        }
        alertController.addAction(cancelAction)

        self.presentViewController(alertController, animated: true, completion: nil)
    }

}

// MARK: UICollectionView

extension ProfileViewController: UICollectionViewDataSource, UICollectionViewDelegate, UIGestureRecognizerDelegate {
    
    enum ProfileSection: Int {
        case Header = 0
        case Footer
        case Master
        case Learning
        case SeparationLine
        case SocialAccount
    }
    
    func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return 6
    }

    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {

        switch section {

        case ProfileSection.Header.rawValue:
            return 1

        case ProfileSection.Master.rawValue:
            if let profileUser = profileUser {
                switch profileUser {
                case .DiscoveredUserType(let discoveredUser):
                    return discoveredUser.masterSkills.count
                case .UserType(let user):
                    return Int(user.masterSkills.count)
                }
            }

            return 0

        case ProfileSection.Learning.rawValue:

            if let profileUser = profileUser {
                switch profileUser {
                case .DiscoveredUserType(let discoveredUser):
                    return discoveredUser.learningSkills.count
                case .UserType(let user):
                    return Int(user.learningSkills.count)
                }
            }

            return 0

        case ProfileSection.Footer.rawValue:
            return 1

        case ProfileSection.SeparationLine.rawValue:
            return 1
            
        case ProfileSection.SocialAccount.rawValue:

            if let profileUser = profileUser {
                switch profileUser {

                case .DiscoveredUserType(let discoveredUser):
                    return discoveredUser.socialAccountProviders.filter({ $0.enabled }).count

                case .UserType(let user):

                    if user.friendState == UserFriendState.Me.rawValue {
                        return user.socialAccountProviders.count

                    } else {
                        return user.socialAccountProviders.filter("enabled = true").count
                    }
                }
            }

            return 0

        default:
            return 0
        }
    }

    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {

        switch indexPath.section {

        case ProfileSection.Header.rawValue:
            let cell = collectionView.dequeueReusableCellWithReuseIdentifier(headerCellIdentifier, forIndexPath: indexPath) as! ProfileHeaderCell

            if let profileUser = profileUser {
                switch profileUser {
                case .DiscoveredUserType(let discoveredUser):
                    cell.configureWithDiscoveredUser(discoveredUser)
                case .UserType(let user):
                    cell.configureWithUser(user)
                }
            }

            return cell

        case ProfileSection.Master.rawValue:
            let cell = collectionView.dequeueReusableCellWithReuseIdentifier(skillCellIdentifier, forIndexPath: indexPath) as! SkillCell

            if let profileUser = profileUser {
                switch profileUser {
                case .DiscoveredUserType(let discoveredUser):
                    let skill = discoveredUser.masterSkills[indexPath.item]
                    cell.skillLabel.text = skill.localName
                case .UserType(let user):
                    let userSkill = user.masterSkills[indexPath.item]
                    cell.skillLabel.text = userSkill.localName
                }
            }

            return cell

        case ProfileSection.Learning.rawValue:
            let cell = collectionView.dequeueReusableCellWithReuseIdentifier(skillCellIdentifier, forIndexPath: indexPath) as! SkillCell

            if let profileUser = profileUser {
                switch profileUser {
                case .DiscoveredUserType(let discoveredUser):
                    let skill = discoveredUser.learningSkills[indexPath.item]
                    cell.skillLabel.text = skill.localName
                case .UserType(let user):
                    let userSkill = user.learningSkills[indexPath.item]
                    cell.skillLabel.text = userSkill.localName
                }
            }

            return cell

        case ProfileSection.Footer.rawValue:
            let cell = collectionView.dequeueReusableCellWithReuseIdentifier(footerCellIdentifier, forIndexPath: indexPath) as! ProfileFooterCell

            cell.introductionLabel.text = introductionText

            return cell

        case ProfileSection.SeparationLine.rawValue:
            let cell = collectionView.dequeueReusableCellWithReuseIdentifier(separationLineCellIdentifier, forIndexPath: indexPath) as! ProfileSeparationLineCell

            return cell
            
        case ProfileSection.SocialAccount.rawValue:

            if let profileUser = profileUser {

                var providerName = ""

                switch profileUser {

                case .DiscoveredUserType(let discoveredUser):
                    let provider = discoveredUser.socialAccountProviders.filter({ $0.enabled })[indexPath.row]
                    providerName = provider.name

                case .UserType(let user):
                    if user.friendState == UserFriendState.Me.rawValue {
                        let provider = user.socialAccountProviders[indexPath.row]
                        providerName = provider.name

                    } else {
                        let provider = user.socialAccountProviders.filter("enabled = true")[indexPath.row]
                        providerName = provider.name
                    }
                }

                if let socialAccount = SocialAccount(rawValue: providerName) {

                    if socialAccount == .Github {
                        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(socialAccountGithubCellIdentifier, forIndexPath: indexPath) as! ProfileSocialAccountGithubCell

                        cell.configureWithProfileUser(profileUser, socialAccount: socialAccount, githubWork: githubWork, completion: { githubWork in
                            self.githubWork = githubWork
                        })

                        return cell

                    } else {

                        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(socialAccountImagesCellIdentifier, forIndexPath: indexPath) as! ProfileSocialAccountImagesCell

                        var socialWork: SocialWork?

                        switch socialAccount {

                        case .Dribbble:
                            if let dribbbleWork = dribbbleWork {
                                socialWork = SocialWork.Dribbble(dribbbleWork)
                            }

                        case .Instagram:
                            if let instagramWork = instagramWork {
                                socialWork = SocialWork.Instagram(instagramWork)
                            }

                        default:
                            break
                        }

                        cell.configureWithProfileUser(profileUser, socialAccount: socialAccount, socialWork: socialWork, completion: { socialWork in
                            switch socialWork {

                            case .Dribbble(let dribbbleWork):
                                self.dribbbleWork = dribbbleWork
                                
                            case .Instagram(let instagramWork):
                                self.instagramWork = instagramWork
                            }
                        })
                        
                        return cell
                    }
                    
                }
            }

            let cell = collectionView.dequeueReusableCellWithReuseIdentifier(socialAccountCellIdentifier, forIndexPath: indexPath) as! ProfileSocialAccountCell
            return cell

        default:
            let cell = collectionView.dequeueReusableCellWithReuseIdentifier(skillCellIdentifier, forIndexPath: indexPath) as! SkillCell

            return cell
        }
    }

    func collectionView(collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, atIndexPath indexPath: NSIndexPath) -> UICollectionReusableView {

        if kind == UICollectionElementKindSectionHeader {

            let header = collectionView.dequeueReusableSupplementaryViewOfKind(kind, withReuseIdentifier: sectionHeaderIdentifier, forIndexPath: indexPath) as! ProfileSectionHeaderReusableView

            switch indexPath.section {

            case ProfileSection.Master.rawValue:
                header.titleLabel.text = NSLocalizedString("Master", comment: "")

            case ProfileSection.Learning.rawValue:
                header.titleLabel.text = NSLocalizedString("Learning", comment: "")

            default:
                header.titleLabel.text = ""
            }

            if profileUserIsMe {

                header.tapAction = {
                    let storyboard = UIStoryboard(name: "Intro", bundle: nil)
                    let pickSkillsController = storyboard.instantiateViewControllerWithIdentifier("RegisterPickSkillsViewController") as! RegisterPickSkillsViewController

                    pickSkillsController.isRegister = false
                    pickSkillsController.masterSkills = self.masterSkills
                    pickSkillsController.learningSkills = self.learningSkills

                    pickSkillsController.afterChangeSkillsAction = { masterSkills, learningSkills in
                        self.masterSkills = masterSkills
                        self.learningSkills = learningSkills

                        dispatch_async(dispatch_get_main_queue()) {
                            self.updateProfileCollectionView()
                        }
                    }

                    self.navigationController?.pushViewController(pickSkillsController, animated: true)
                }
            }

            return header

        } else {
            let footer = collectionView.dequeueReusableSupplementaryViewOfKind(kind, withReuseIdentifier: sectionFooterIdentifier, forIndexPath: indexPath) as! UICollectionReusableView
            return footer
        }
    }

    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAtIndex section: Int) -> UIEdgeInsets {

        switch section {

        case ProfileSection.Header.rawValue:
            return UIEdgeInsets(top: 0, left: 0, bottom: sectionBottomEdgeInset, right: 0)

        case ProfileSection.Master.rawValue:
            return UIEdgeInsets(top: 0, left: sectionLeftEdgeInset, bottom: 15, right: sectionRightEdgeInset)

        case ProfileSection.Learning.rawValue:
            return UIEdgeInsets(top: 0, left: sectionLeftEdgeInset, bottom: sectionBottomEdgeInset, right: sectionRightEdgeInset)

        case ProfileSection.Footer.rawValue:
            return UIEdgeInsets(top: 20, left: 0, bottom: 20, right: 0)
            
        case ProfileSection.SeparationLine.rawValue:
            return UIEdgeInsets(top: 40, left: 0, bottom: 30, right: 0)

        case ProfileSection.SocialAccount.rawValue:
            return UIEdgeInsets(top: 0, left: 0, bottom: 30, right: 0)

        default:
            return UIEdgeInsetsZero
        }
    }

    func collectionView(collectionView: UICollectionView!, layout collectionViewLayout: UICollectionViewLayout!, sizeForItemAtIndexPath indexPath: NSIndexPath!) -> CGSize {

        switch indexPath.section {

        case ProfileSection.Header.rawValue:
            return CGSize(width: collectionViewWidth, height: collectionViewWidth * profileAvatarAspectRatio)

        case ProfileSection.Master.rawValue:
            var skillLocalName = ""

            if let profileUser = profileUser {
                switch profileUser {

                case .DiscoveredUserType(let discoveredUser):
                    skillLocalName = discoveredUser.masterSkills[indexPath.item].localName

                case .UserType(let user):
                    let userSkill = user.masterSkills[indexPath.item]
                    skillLocalName = userSkill.localName
                }
            }

            let rect = skillLocalName.boundingRectWithSize(CGSize(width: CGFloat(FLT_MAX), height: SkillCell.height), options: .UsesLineFragmentOrigin | .UsesFontLeading, attributes: skillTextAttributes, context: nil)

            return CGSize(width: rect.width + 24, height: SkillCell.height)

        case ProfileSection.Learning.rawValue:
            var skillLocalName = ""

            if let profileUser = profileUser {
                switch profileUser {

                case .DiscoveredUserType(let discoveredUser):
                    skillLocalName = discoveredUser.learningSkills[indexPath.item].localName

                case .UserType(let user):
                    let userSkill = user.learningSkills[indexPath.item]
                    skillLocalName = userSkill.localName
                }
            }

            let rect = skillLocalName.boundingRectWithSize(CGSize(width: CGFloat(FLT_MAX), height: SkillCell.height), options: .UsesLineFragmentOrigin | .UsesFontLeading, attributes: skillTextAttributes, context: nil)

            return CGSize(width: rect.width + 24, height: SkillCell.height)

        case ProfileSection.Footer.rawValue:
            return CGSize(width: collectionViewWidth, height: footerCellHeight)

        case ProfileSection.SeparationLine.rawValue:
            var enabled = true

            if let profileUser = profileUser {
                switch profileUser {

                case .DiscoveredUserType(let discoveredUser):
                    enabled = discoveredUser.socialAccountProviders.filter({ $0.enabled }).count > 0

                case .UserType(let user):
                    if user.friendState != UserFriendState.Me.rawValue {
                        enabled = user.socialAccountProviders.filter("enabled = true").count > 0
                    }
                }
            }

            return enabled ? CGSize(width: collectionViewWidth, height: 1) : CGSizeZero
            
        case ProfileSection.SocialAccount.rawValue:
            return CGSize(width: collectionViewWidth, height: 40)

        default:
            return CGSizeZero
        }
    }

    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {

        if section == ProfileSection.Master.rawValue || section == ProfileSection.Learning.rawValue {
            return CGSizeMake(collectionViewWidth, 40)

        } else {
            return CGSizeZero
        }
    }

    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
        return CGSizeZero
    }
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        
        if indexPath.section == ProfileSection.Learning.rawValue || indexPath.section == ProfileSection.Master.rawValue {

            var skillID: String = ""
            var skillLocalName: String = ""
            
            if let profileUser = profileUser {

                switch profileUser {

                case .DiscoveredUserType(let discoveredUser):
                    if indexPath.section == ProfileSection.Learning.rawValue {
                        let skill = discoveredUser.learningSkills[indexPath.item]
                        skillID = skill.id
                        skillLocalName = skill.localName

                    } else if indexPath.section == ProfileSection.Master.rawValue {
                        let skill = discoveredUser.masterSkills[indexPath.item]
                        skillID = skill.id
                        skillLocalName = skill.localName
                    }

                case .UserType(let user):
                    if indexPath.section == ProfileSection.Learning.rawValue {
                        let userSkill = user.learningSkills[indexPath.item]
                        skillID = userSkill.skillID
                        skillLocalName = userSkill.localName

                    } else if indexPath.section == ProfileSection.Master.rawValue {
                        let userSkill = user.masterSkills[indexPath.item]
                        skillID = userSkill.skillID
                        skillLocalName = userSkill.localName
                    }
                }
            }
            
            self.performSegueWithIdentifier("showSkillHome", sender: ["skillID": skillID, "skillLocalName": skillLocalName])
            
        } else if indexPath.section == ProfileSection.SocialAccount.rawValue {

            if let profileUser = profileUser {

                var providerName = ""

                switch profileUser {

                case .DiscoveredUserType(let discoveredUser):
                    let provider = discoveredUser.socialAccountProviders.filter({ $0.enabled })[indexPath.row]
                    providerName = provider.name

                case .UserType(let user):

                    if user.friendState == UserFriendState.Me.rawValue {
                        let provider = user.socialAccountProviders[indexPath.row]
                        providerName = provider.name

                    } else {
                        let provider = user.socialAccountProviders.filter("enabled = true")[indexPath.row]
                        providerName = provider.name
                    }
                }

                if let socialAccount = SocialAccount(rawValue: providerName) {

                    if profileUser.enabledSocialAccount(socialAccount) {
                        performSegueWithIdentifier("showSocialWork\(socialAccount)", sender: providerName)

                    } else {
                        if profileUserIsMe {
                            performSegueWithIdentifier("presentOAuth", sender: providerName)
                        }
                    }
                }
            }
        }
    }
}

extension ProfileViewController: UIScrollViewDelegate {

    func scrollViewDidScroll(scrollView: UIScrollView) {
        if scrollView.contentOffset.y < -300 {
            YepAlert.alert(title: "Hello", message: "My name is NIX. How are you?", dismissTitle: "I'm fine.", inViewController: self, withDismissAction: nil)
        }
    }
}

