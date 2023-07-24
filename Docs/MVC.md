# MVC 文档

文章写于`d88ebd7adf19109b0326587c7ccbd11d1f3e4716`上，部分代码内容&位置可能变动，请注意通用性。

## ChangeLog

* `6c40582161e22b832a63e947d09d811880504805` 更新了部分过时内容。

## Code Structure

按照MVC的规范，我们将代码分为三个部分：Model、View、Controller。

这些分离出来的代码，最开始并不是参考MVC的设计规范而得到的，而是随着代码的增长，自然而然形成的分离，所以下面所述的设计中，有写会以`Delegate`的名字指代`Controller`。从而可以将其理解为`View`和`Model`的中间人。

代码结构简述如下：

```txt
Models/
    __model_name__/
        __model_name__.swift
        __model_name__Delegate.swift
Views/
    __model_name__/
        __view_name__.swift
        // sometimes comes with a __view_name__ + Preview.swift to show that on HomeView
```

将`Model`与`Delegate`存放在同一目录下是实践中最容易理解的方式，因为`Model`和`Delegate`是一一对应的。`View`则是根据`Model`的不同而不同的，所以将其放在`Views`目录下，再根据`Model`的不同进行分类。

> 在[这个PR](https://github.com/Life-USTC/Life-USTC/pull/35)之后，USTC相关的逻辑被单独重构到了外面，也就是说所有非通用的`Model`和`Delegate`都应该存放在`Schools/`下面，`Model`中存放了通用的`Score` `Exam` `Course`等等，并提供了这些`model`通用`delegate`的实现方法（例如`ExamDelegateProtocol`）

## AsyncDataDelegate Design

由于一般来说，`Delegate`所需的操作都是异步的，所以如何合理讲异步的状态、结果同步到`View`上是一个需要考虑的问题。

### History

早期，采取过一个统一封装的结构`AsyncView`，在定义时，要将`makeView(data: D)`，`loadData() async throws -> D`, `refreshData() async throws -> D`传入`AsyncView`中，并由其管理整个生命周期。

在代码量较小的时候，这个封装的模式问题不大。但在UI设计更加复杂的时候，这出现了不少问题：

* `AsyncView`的定义过于复杂，需要传入的参数过多，而且范型的写法过于难以阅读，维护量大。
* `makeView(data: D)`中对data无控制权，aka. 无法在`makeView`中对`data`进行修改，只能在`loadData`和`refreshData`中进行修改，这导致自由度过小，而部分UI设计并不刷新整个View，无法作为新的feature引入`AsyncView`，使得有写食之无味弃之可惜的感觉。
    例如`CurriclumView`最终并未采用这种设计，因为这个View需要在View中刷新data，但这个传入的参数跟单纯的刷新不尽相同，不能直接通过调用`refreshData`来实现。引入其他函数定义又会导致不够通用，从而导致设计上的失败。

    这些问题曾经有着通过`makeView(data: D) -> makeView(data: Binding<D>)`来解决，但这样做的结果，在编写中，反而让人怀疑是否需要`AsyncView`这个定义本身……

### Current Design

> 下面的文档中，`forceUpdate()`已被更名为`refreshCache()`，并且无需再去刷新`data`，来确保刷新失败后`cache`还能独立支撑`parseCache()`，这在事实上只是一个建议，而不是强制性的要求。

首先是利用Swift Combine的`ObservableObject`来实现`AsyncDataDelegate`的定义，这样可以将`AsyncDataDelegate`的定义简化为：

```swift
protocol AsyncDataDelegate: ObservableObject {
    associatedtype D

    var data: D { get set }
    var placeholderData: D { get }
    var status: AsyncViewStatus { get set }
    var requireUpdate: Bool { get }
    func parseCache() async throws -> D
    func forceUpdate() async throws
    func retrive() async throws -> D
    func userTriggerRefresh(forced: Bool)
}
```

我们在这里提取一个例子`ExamDelegate`，来讲解如何使用`AsyncDataDelegate`。

```swift
class ExamDelegate: UserDefaultsADD, LastUpdateADD {
    // Protocol requirements
    typealias D = [Exam]
    var lastUpdate: Date?
    var cacheName: String = "UstcUgAASExamCache"
    var timeCacheName: String = "UstcUgAASLastUpdateExams"
    var status: AsyncViewStatus = .inProgress {
        willSet {
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }
    var cache: [Exam] = []
    var data: [Exam] = [] {
        willSet {
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }

    // ...
}
```

这些定义是为了适应`AsyncDataDelegate`，其中`ADD`是`AsyncDataDelegate`的缩写（~~这个缩写挺烂的~~）

以上的定义，大部分都不需要在`Delegate`中管理生命周期，不需要手动update，不需要手动parse，不需要手动retrive，只需要在`Delegate`中定义好`cacheName`和`timeCacheName`，以及`parseCache`和`forceUpdate`的实现即可。

（写在具体的定义中，仅仅是因为extension中不能存储属性，所以只能写在具体的定义中）

```swift
    // ...
    func parseCache() async throws -> [Exam] {
        // ...
    }
    func forceUpdate() async throws {
        // ...
        try await afterForceUpdate()
    }

    init() {
        // ...

        afterInit()
    }
```

这些是需要提供的定义，其余的函数、生命周期管理均由`AsyncDataDelegate`来管理。

在这样的定义下，你无需关心`cache`何时可用，无需关心`data`何时可用，无需关心`status`何时变化，只需要关心`cache`怎样更新、`cache -> data` 的转换即可。

> ~~在写这个文档时，我注意到其实无需在`forceUpdate()`的结尾中加入`afterForceUpdate()`来存储，可直接返回cache.Type；可能唯一需要的是init中的`afterInit()`，因为无法在范型定义中规范这个函数的调用。~~
> ~~这些想法会在日后作出更新，但这部分文档不会收到影响，更新之后也不会在暴露的接口中存在问题，所以暂时不会进行修改。~~
>
> Updates: 这个想法最终被我砍掉了，原因主要是无法知晓cache存放的位置，是文件？userDefaults？还是压根不做缓存？所以无法在`forceUpdate()`中直接返回cache，而是需要在`forceUpdate()`中调用`afterForceUpdate()`来确保cache的存储。（在有些子类Protocol中也可不实现这类方法，比如`USTC+Catalog.swift`中无缓存的方案）

### Usage

> 使用这些子类Protocol提高了维护的效率，但是也限制了一些自由度，所以如果你想要自定义`cache`的存储位置，或者自定义`cache -> data`的转换，可以直接使用`AsyncDataDelegate`。

在使用`AsyncDataDelegate`时，你需要做的仅仅是：

1. 定义`AsyncDataDelegate`的范型，例如`ExamDelegate: LastUpdateADD, UserDefaultsADD`。
    其中`LastUpdateADD`确定了刷新的规则：根据上一次刷新的时间 + 给出的TimeInterval来判断是否需要刷新。
    `UserDefaultsADD`确定了缓存的位置：在`UserDefaults`中，以`cacheName`和`timeCacheName`为key进行存储。

    **特别值得注意的是，这两者之间并无依赖关系**
2. 定义`AsyncDataDelegate`的`cacheName`和`timeCacheName`，以及`parseCache`和`forceUpdate`的实现。
    其中`cacheName`和`timeCacheName`是`UserDefaults`中的key，`parseCache`和`forceUpdate`是`cache -> data`的转换。

    **你需要保障这些名字不重复，并且定义的相对稳定，在版本更新前后，如果想继续调用上一版本中缓存的数据，不能更改对应的名字**
3. 有时，`cache`和`data`的类型没有过多的限制，多数情况下`cache`是`swiftyJSON`的`JSON`，但由于采用了范型的定义，并不局限于`JSON`，事实上可采用任何`Codable`的类型，甚至可以保持和cache一致。
4. `parse`的结果会直接更新到`data`中，并直接反映到UI上，所以你需要保障`parse`的结果是正确的，如果出现问题应当及时的raise error，来避免在UI上出现异常的渲染，这可能导致整个程序的崩溃。
    这也意味着你可以在`parse`中做一些额外的操作，例如对`data`进行排序，或者对`data`进行过滤，这些操作都不会影响到`cache`，但会影响到`data`，从而影响到UI的渲染。

### View

在创建UI时，`AsyncDataDelegate`提供了很优雅的模型设计：

```swift
struct ExamView: View {
    @StateObject var delegate = ExamDelegate()
    var exams: [Exam] {
        delegate.data
    }
    var status: AsyncViewStatus {
        delegate.status
    }
    var body: some View {
        // make view using exams
        .asyncViewStatusMask(status: status)
        .refreshable {
            // await delegate.forceUpdate()
            delegate.userTriggerRefresh()
        }
    }
}
```

**一些优点：**

* 在这里，你可以直接使用`delegate.data`来获取数据，而不需要关心`delegate`何时更新，何时可用，何时变化，何时需要刷新。
* 需要刷新时，也不需要手动调用`delegate.forceUpdate() -> self.exams = delegate.parseCache()`，而是直接调用`delegate.userTriggerRefresh()`即可。
* 这样的设计，使得UI的代码变得非常简洁，而且不需要关心`delegate`的生命周期，只需要关心`delegate`的数据即可。
* 同时由于`protocol`的设计，也不会存在`AsyncView`那样的局限性，如果需要额外的函数，可以直接在`delegate`中定义，而且可直接在`View`上调用。`AsyncViewDelegate`只是提供了一种模型，而不是强制性的要求。

### AsyncViewStatus 的补充说明

```swift
/// Instruct how the view should appear to user
enum AsyncViewStatus {
    case inProgress
    case cached
    case success
    case failure(String?)
    case lethalFailure(String?)

    var canShowData: Bool
    var isRefreshing: Bool
    var hasError: Bool
    var errorMessage: String
}

```

`AsyncViewStatus`是一个枚举类型，用来指示UI应该如何展示给用户。

* `inProgress`：正在刷新，此时不应该展示任何数据，而是应该展示一个`ProgressView`，由于data时刻都是non-optional的，传递给View并不应该导致crash，所以会以placeholder+模糊的方式占位。
* `cached`：刷新成功，但是数据并不是最新的，此时应该展示数据，但是应该在数据的上方展示一个`ProgressView`，来提示用户数据并不是最新的，并且数据正在刷新。此状态不能是最终状态，一定会转换为`success`或者`failure`。
* `success`：刷新成功，此时应该正常展示数据。
* `failure`：刷新失败，但是数据仍然是可用的，此时应该正常展示数据，但是应该在数据的上方展示一个`Image(systemName: "xmark.octagon.fill")`，来提示用户刷新失败。
* `letahalFailure`：刷新失败，且数据不可用，此时应该展示一个`Image(systemName: "xmark.octagon.fill")`，来提示用户刷新失败，并且数据不可用（与`inProgress`类似，用placeholderData替换data，并模糊占位。
    > 多用于第一次打开应用时无任何初始数据且无法获取新数据。

在一些特殊场景中，并不存在上述的状态。但请不要盲目引入新的case，参考下面这个例子：

```swift

.toolbar {
    Button {
        Task {
            saveToCalendarStatus = .inProgress
            do {
                try await Exam.saveToCalendar(exams)
                saveToCalendarStatus = .success
            } catch {
                saveToCalendarStatus = .failure
            }
        }
    } label: {
        Image(systemName: "square.and.arrow.down")
            .asyncViewStatusMask(status: saveToCalendarStatus)
    }
}
```

在这个例子中，`saveToCalendarStatus`并不是一个`AsyncDataDelegate`，而是一个`@State`，但是我们仍然可以使用`asyncViewStatusMask`来展示不同的状态。问题在于，这个值应该怎样给初始值？显然上面的三个case都是不合理的，因为在用户没有操作之前，不应该展示任何状态。在引入新的case之前，请考虑Optional的设计：

```swift
    // ExamView.swift
    @State var saveToCalendarStatus: AsyncViewStatus? = nil

    //AsyncView.swift
    struct AsyncViewStatusMask: ViewModifier {
        var status: AsyncViewStatus?

        func body(content: Content) -> some View {
            ZStack {
                if status?.canShowData ?? true {
                    content
                        .opacity(status?.isRefreshing ?? false ? 0.5 : 1.0)
                } else {
                    Color.white
                }

                if status?.isRefreshing ?? false {
                    ProgressView()
                }

                if status == .failure {
                    Image(systemName: "xmark.octagon.fill")
                        .foregroundColor(.red)
                }
            }
        }
    }

    extension View {
        func asyncViewStatusMask(status: AsyncViewStatus?) -> some View {
            modifier(AsyncViewStatusMask(status: status))
        }
    }
```

在这里，我们使用了`Optional`来表示`saveToCalendarStatus`的初始值，这样就可以避免在初始状态下展示任何状态。

同时，我们也可以在`AsyncViewStatusMask`中直接接受了`Optional`的参数，使整段代码更加简洁。
