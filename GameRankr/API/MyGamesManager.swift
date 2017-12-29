import Foundation
import Apollo

protocol APIMyGamesManagerDelegate : AuthenticatedAPIErrorDelegate, AnyObject {
    func handleUpdates()
}

class MyGamesManager : APIMyGamesDelegate, APIRankDelegate, APIDestroyRankingDelegate {
    static let sharedInstance = MyGamesManager()
    
    var rankings : [RankingBasic]
    var rankingsLoading : [RankingBasic]?
    var rankingsByGameId = [GraphQLID:RankingBasic]()
    
    var delegates = [APIMyGamesManagerDelegate]()
    var loadingCount = 0
    
    init() {
        do {
            rankings = try LocalSQLiteManager.sharedInstance.getRankings()
            for ranking in rankings {
                rankingsByGameId[ranking.game.id] = ranking
            }
        }
        catch {
            NSLog("error getting rankings from sql lite")
            rankings = []
        }
        if (api.signed_in) {
            load()
        }
    }
    
    func load() {
        if (loading()) {
            NSLog("MyGamesManager was already loading")
            return
        }
        if (!api.signed_in) {
            NSLog("MyGamesManager - cannot load, not signed in yet")
            return
        }
        self.loadingCount += 1
        rankingsLoading = [RankingBasic]()
        api.myGames(delegate: self)
    }
    
    func clear() {
        rankings = [RankingBasic]()
        LocalSQLiteManager.sharedInstance.clearRankings()
        notifyDelegates()
    }
    
    func loading() -> Bool {
        return loadingCount > 0
    }
    
    
    func register(delegate: APIMyGamesManagerDelegate) {
        self.delegates.append(delegate)
    }
    
    func unregister(delegate: APIMyGamesManagerDelegate) {
        if let index = self.delegates.index(where: {$0 === delegate}) {
            self.delegates.remove(at: index)
        }
    }
    
    subscript(index : Int) -> RankingBasic? {
        return rankings[index]
    }
    
    func count() -> Int {
        return rankings.count
    }
    
    func getRanking(gameId : GraphQLID) -> RankingBasic? {
        return rankingsByGameId[gameId]
    }
    
    func rankPort(portId: GraphQLID, ranking: Int? = nil, removeRanking: Bool = false, review: String? = nil, addShelfId: GraphQLID? = nil, removeShelfId: GraphQLID? = nil) {
        loadingCount += 1
        api.rankPort(portId: portId, ranking: ranking, removeRanking: removeRanking, review: review, addShelfId: addShelfId, removeShelfId: removeShelfId, delegate: self)
    }
    
    func destroyRanking(portId: GraphQLID) {
        loadingCount += 1
        api.destroyRanking(portId: portId, delegate: self)
    }
    
    func handleAPIMyGames(response: MyGamesQuery.Data.MyGame) {
        let additionalRankings = response.edges!.map({$0!.ranking!.fragments.rankingBasic})
        if (!additionalRankings.isEmpty) {
            rankingsLoading!.append(contentsOf: additionalRankings)
            if (response.pageInfo.hasNextPage){
                api.myGames(after: response.pageInfo.endCursor, delegate: self)
            }
        }
        if (!response.pageInfo.hasNextPage) {
            doneLoading()
        }
    }
    
    private func doneLoading() {
        loadingCount -= 1
        var rankingsByGameIdLoading = [GraphQLID: RankingBasic]()
        rankingsLoading!.forEach({ ranking in
            rankingsByGameIdLoading[ranking.game.id] = ranking
        })
        
        self.rankings = rankingsLoading!
        self.rankingsLoading = nil
        self.rankingsByGameId = rankingsByGameIdLoading
        LocalSQLiteManager.sharedInstance.persistRankings(rankings: rankings)
        notifyDelegates()
    }
    
    private func addRanking(_ ranking: RankingBasic) {
        let gameId = ranking.game.id
        rankingsByGameId[gameId] = ranking
        rankings.insert(ranking, at: 0)
    }
    
    func handleAPI(ranking: RankingBasic) {
        deleteRankingFor(gameId: ranking.game.id)
        addRanking(ranking)
        loadingCount -= 1
        notifyDelegates()
    }
    
    private func deleteRankingFor(gameId: GraphQLID) {
        if let oldRanking = rankingsByGameId.removeValue(forKey: gameId) {
            if let oldIndex = rankings.index(where: {$0.id == oldRanking.id}) {
                rankings.remove(at: oldIndex)
            }
        }
    }
    
    func notifyDelegates() {
        delegates.forEach{$0.handleUpdates()}
    }
    
    
    func handleAPIAuthenticationError() {
        for delegate in delegates {
            delegate.handleAPIAuthenticationError()
        }
    }
    
    func handleAPI(error: String) {
        loadingCount -= 1 //yuck!
        //??? - if multiple delegates all try and pop alerts - is that a problem?
        NSLog("MyGamesManager encountered API Error: \(error)")
        delegates.forEach{$0.handleAPI(error: error)}
    }
    
    func handleAPIRankingDestruction(ranking: DestroyRankingMutation.Data.Ranking) {
        loadingCount -= 1
        let gameId = ranking.game.id
        deleteRankingFor(gameId: gameId)
        notifyDelegates()
    }
}
