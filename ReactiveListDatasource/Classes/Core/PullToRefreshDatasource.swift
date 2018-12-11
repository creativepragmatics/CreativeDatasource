import Foundation

public protocol PullToRefreshDatasource : DatasourceProtocol where State.LIT == PullToRefreshLoadImpulseType { }
