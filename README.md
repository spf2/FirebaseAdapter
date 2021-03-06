# FirebaseAdapter - UI toolkit for Firebase

FirebaseAdapter is a Swift UI toolkit for [Firebase](https://www.firebase.com) that makes building scalable UIKit applications with Firebase easier.  It surfaces Firebase queries as streams that are synched with Firebase, fetched incrementally, and can be merged or split into multiple sections.  These streams can then be plugged into UITableViews or UICollectionViews.  It also includes a [persistence layer](#persistence-layer) that maps application objects to firebase path templates.

## Installing FirebaseAdapter

Using Cocoapods, add to your `Podfile`:

```
pod 'FirebaseAdapter', '~> 0.3'
```

And, if you don't have it already:

```
platform :ios, '8.0'
use_frameworks!
```

(NOTE the code is not currently in cocoapods directory, so you'll need to fetch it like: ```git clone https://github.com/spf2/FirebaseAdapter.git```)

## Getting Started with FirebaseAdapter:

If you don't have one already, sign up for a [Firebase account](https://www.firebase.com/signup/).

This adapter uses the term "streams" to refer to scalable collections that can be fetched incrementally.  To work with streams in FirebaseAdapter, you'll want to know about these classes:

Class  |  Description
-------|-------------
BaseItem | Base class for objects that appear in streams.
StreamBase | This is the main class that exposes a Firebase query as a Stream.
StreamBaseDelegate | Delegate that is notified of stream changes.
StreamTableViewAdapter | Adapter from streams to UITableViews.
PartitionedStream | Split a stream into multiple sections.
TransientStream |  Stream that's not connected to Firebase.
UnionStream |  Stream for merging multiple streams.
QueryBuilder | Helper for composing Firebase queries.

To get started, you'll need to build from BaseItem and StreamBase.  Additionally, StreamTableViewAdapter provides some convenient functionality to connect streams with tables.  Here's the basic outline:

```swift

MyItem.swift

class MyItem : BaseItem {
  var name: String?

  func update(dict: [String: AnyObject) {
    super.update(dict)
    name = dict["name"] as? String
  }

  var dict: [String: AnyObject] {
    var d = super.dict
    d["name"] = name
    return d
  }
}

MyViewController.swift

class MyViewController : UIViewController {
  var stream: StreamBase!
  var adapter: StreamTableViewAdapter!
  // etc...

  override func viewDidLoad() {
    // etc...

    let firebaseRef = Firebase(url:"https://<YOUR-FIREBASE-APP>.firebaseio.com/")
    stream = StreamBase(type: MyItem.self, ref: firebaseRef)
    adapter = StreamTableViewAdapter(tableView: tableView)
    stream.delegate = adapter
  }
}

extension MyViewController : UITableViewDataSource {
  func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return stream.count
  } 

  func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCellWithIdentifier("MyCell", forIndexPath: indexPath)
    let item = stream[indexPath.row] as! MyItem
    cell.titleLabel?.text = item.name 
    return cell
  }
}
```

## Multiple Sections with PartitionedStream

PartitionedStream allows you to define a partition function for splitting a stream into mulitple sections.  This is useful, eg, in splitting a roster of users into organizers and participants.  Building off of the previous example:

```swift

User.swift

class User : BaseItem {
  var isOrganizer: Bool
  // etc...
}

MyViewController.swift

class MyViewController : UIViewController {
  var pstream: PartitionedStream!
  // etc...

  override func viewDidLoad() {
    // etc...
    pstream = PartitionedStream(stream: stream, sectionTitles: ["organizers", "participants"]) { ($0 as! User).isOrganizer ? 0 : 1 }
    pstream.delegate = adapter
  }
} 

extension MyViewController : UITableViewDataSource {
  func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return pstream[section].count
  } 

  func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCellWithIdentifier("MyCell", forIndexPath: indexPath)
    let item = pstream[indexPath] as! User  // Index partitioned stream with whole NSIndexPath
    cell.titleLabel?.text = item.name 
    return cell
  }

  func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    return pstream.sectionTitles[section]
  }
}

```

## Multiple Sections with Multiple Streams

PartitionedStream is convenient to use, but if the underlying data has hundreds or more elements you'll need to provide limits per section.  You can do this by constructing multiple sections like this:

```swift

class MyViewController : UIViewController {
  var organizerStream: StreamBase!
  var participantStream: StreamBase!
  var organizerAdapter: StreamTableViewAdapter!
  var participantAdapter: StreamTableViewAdapter!
  // etc...

  override func viewDidLoad() {
    // etc...
    let organizerQuery = QueryBuilder(ref)
    organizerQuery.limit = 100
    organizerQuery.ordering = .Child("is_organizer")
    organizerQuery.start = true
    organizerStream = StreamBase(type: User.self, queryBuilder: organizerQuery)
    organizerAdapter = StreamTableViewAdapter(tableView: tableView, section: 0)

    let participantQuery = QueryBuilder(ref)
    participantQuery.limit = 100
    participantQuery.ordering = .Child("is_organizer")
    participantQuery.end = false
    participantStream = StreamBase(type: User.self, queryBuilder: participantQuery)
    participantAdapter = StreamTableViewAdapter(tableView: tableView, section: 1)
  }
}
  
extension MyViewController : UITableViewDataSource {
  func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return (section == 0) ? organizerStream.count : participantStream.count
  } 

  func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCellWithIdentifier("MyCell", forIndexPath: indexPath)
    let user: User
    if indexPath.section == 0 {
      user = organizerStream[indexPath.row] as! User
    } else {
      user = participantStream[indexPath.row] as! User
    }
    // etc...
    return cell
  }
}
```

## Placeholders and Incremental Fetching with TransientStream and UnionStream

Chat histories can grow long, so it's important to enable them to be incrementally fetched.  To do this, we need to be able to insert temporary placeholders into the table to provide a ui for the fetch, and to actually perform the additional fetch.  There are further details (such as knowing the actual size of the stream!), but this is a rough sketch of how this would work:

```swift

class MyViewController : UIViewController {
  let maxToFetch = 100
  var stream: StreamBase!
  var unionStream: UnionStream!
  var transientStream: TransientStream!
  var fetchmore: FetchMoreItem?

  override func viewDidLoad() {
    // etc...
    stream = StreamBase(type: MyItem.self, ref: firebaseRef, ascending: false, limit: maxToFetch)
    transient = TransientStream()
    unionStream = UnionStream(sources: stream, transient)
    unionStream.delegate = self
  }

  func fetchMoreTapped(sender: UIButton) {
    stream.fetchMore(maxToFetch, start: stream[0].key!) {
      transient.remove(fetchmore)
      fetchmore = nil
    }
  }
}
```

Here we extend the StreamBaseDelegate rather than use the StreamTableViewAdapter because we need to manipulate state in the controller.

```swift
extension MyViewController : StreamBaseDelegate {
  override func streamDidFinishInitialLoad(error: NSError?) {
    super.streamDidFinishInitialLoad(error)
    if stream.count > maxToFetch {
      fetchmore = FetchMoreItem(key: dropLast(stream[0].key))
      transient.add(fetchmore)
    }
  }
}

```

# Persistence Layer

FirebaseAdapter also includes a persistence layer that uses a declarative approach: you state where something is stored, and the layer takes care of the rest.  For example,

```swift
registry.resource(Group.self, "/group/@")
registry.resource(GroupMessage.self, "/group_message/$group/@")
```

This states that groups are stored under "/group", and messages, which are logically contained in groups, under "/group_message".  (Recall that it's not a good practice to store them under "/group", say in "/group/$group/message/@", because fetches of the group would also fetch all of the messages.)  

The "@" means that an auto-id is generated for create operations, and the object's key is used for updates and destroys.  The "$" means that the value must be looked up using a ResourceContext... more on that below.

To use the persitence layer, you'll want to know about these classes:

Class  |  Description
-------|-------------
ResourceBase | Core of persistence layer.
ResourceContext | Helper for managing context in persistence layer.
ResourceRegistry | Protocol for registering resources.


## Registering Resources with Persistence Layer

You register resources with an the ResourceBase using the ResourceRegistry protocol.  One approach is to put the ResourceBase in a singleton.  For example:

```swift

Environment.swift

class Environment {
  var resourceBase: ResourceBase!

  static let sharedEnv: Environment = {
    let env = Environment()
    let firebase = Firebase(url: "https://<YOUR-FIREBASE-APP>.firebaseio.com")
    env.resourceBase = ResourceBase(firebase: firebase)

    let registry: ResourceRegistry = env.resourceBase
    registry.resource(Group.self, "/group/@")
    registry.resource(GroupMessage.self, "/group_message/$group/@")
    // ...

    return env
  }()
}

```

## Using the ResourceContext Stack

In the initial view controller, use the Environment singleton to create the root resource context:

```swift

InitialViewController.swift

class InitialViewController : UIViewController {
  var rootResourceContext: ResourceContext!
  // ...
  
  override func viewDidLoad() {
    super.viewDidLoad()
    rootResourceContext = ResourceContext(base: Environment.sharedEnv.resourceBase, resources: nil)
    // ...
```

Now, this view controller can now create, update or delete Groups using the root resource context.  For example:


```swift
let group = Group()
group.name = "group name"
rootResourceContext.create(group)
```

Recall that "$group" in "/group_message/$group/@" indicates a context key which must be filled in in order to persist a GroupMessage.  The ResourceContext is responsible for doing this.  Say you had a GroupViewController which allows users to message groups.  In your initial view controller, before pushing the group view controller onto your navigation controller, you'd do something like this:

```swift
override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
  switch(segue.destinationViewController) {
  case let groupVC as GroupViewController:
    groupVC.resourceContext = resourceContext.push(["group": sender as! Group])
    // ...
```

Now, when you call ```resourceContext.create(GroupMessage())``` in GroupViewController it will know how to resolve the key "$group".  Similarly, if you went deeper and could "like" messages in groups, you could do that by pushing yet another ResourceContext onto the stack transiently.  That might look like:

```swift
func messageLikeTouched(sender: MessageLikeControl) {
  resourceContext.push(["message": sender.message]).create(MessageLike())
}
```

## Counters

It's also possible to specify counters which get incremented or decremented when objects are created or destroyed.  Say you wanted to keep track of how many messages were in your group.  You'd register a counter like:

```swift
registry.counter(Group.self, "message_count", GroupMessage.self)
```

The ResourceBase will take care of incrementing and decrementing the "message_count" when messages are created and destroyed.  Since groups are registered under "/group/@", this counter will appear here: "/group/$group_key/message_count".  

Note that this counter is maintained client-side, and so can become inconsistent over time.  For example, Firebase [transactions are not persisted across app restarts](https://www.firebase.com/docs/ios/guide/offline-capabilities.html), so if the user makes changes while offline, and then closes the app, counters may not be updated.

## Extending ResourceBase

ResourceBase has a number of hooks for subclasses to use when extending it.  There are hooks for create, update and destroy that are invoked before, after commit to local storage, and after commit to remote storage.  There is also a hook for [logging so a server can handle side effects](https://medium.com/@spf2/action-logs-for-firebase-30a699200660).

# Building the Example

A simple example project is included.  To build it:

```
$ git clone https://github.com/spf2/FirebaseAdapter.git
$ cd FirebaseAdapter/FirebaseAdapterExample
$ pod install
$ open FirebaseAdapterExample.xcworkspace
```

Set the active scheme to FirebaseAdapterExample, and then hit command-R.

# Comparison with FirebaseUI-iOS

An alternative library to consider is [FirebaseUI-iOS](https://github.com/firebase/FirebaseUI-iOS).  It is the official client library for Firebase.  It's written in Objective-C instead of Swift, and is simpler.

FirebaseAdapter grew out of building Movem3nt, a complex social application, and addresses a variety of problems encountered in doing so.  For example, iOS table views will auto-scroll if content is inserted on top, but Firebase appends new data to the bottom.  To make these work well together for messaging-type apps, one needs to invert both the firebase collection and the table view.  

FirebaseAdapter also makes it easy to add more advanced functionality like splitting a collection into multiple table sections, and inserting transient content into the table like a "fetch more" control for incremental fetching.

The resource layer makes it much to keep your database persistence logic and ui view controller logic separate. It also provides the convenient counter feature.

Presently, there are no plans for FirebaseAdapter to support Android or JS.  Let me (spf2) know if using FirebaseAdapter on those platforms is interesting to you.

# History

This code is a fork of code I wrote at movem3nt/StreamBaseKit v0.2.  No further development is planned within the Movem3nt project, so I've put this on my personal account, renamed it to FirebaseAdapter, and called it version 0.3.
