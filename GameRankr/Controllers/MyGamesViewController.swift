import UIKit

class MyGamesViewController: UIViewController, UITableViewDataSource, UITableViewDelegate,  APIMyGamesDelegate, AlertAPIErrorDelegate {
    
    
    var rankings: [MyGamesQuery.Data.Ranking] = []
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var signedInView: UIView!
    @IBOutlet weak var signedOutView: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if (api.signed_in) {
            signedOutView.isHidden = true
            signedInView.isHidden = false
            api.getMyGames(delegate: self)
        }
        else {
            signedOutView.isHidden = false
            signedInView.isHidden = true
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rankings.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let ranking = rankings[indexPath.row]
        cell.textLabel!.text = ranking.game.title
        
        
        if (ranking.port.smallImageUrl != nil) {
            cell.imageView?.kf.indicatorType = .activity
            cell.imageView?.kf.setImage(with: URL(string: ranking.port.smallImageUrl!)!, placeholder: PlaceholderImages.game)
        }
        return cell
    }
    
    
    func handleAPIMyGames(rankings: [MyGamesQuery.Data.Ranking]) {
        self.rankings = rankings
        DispatchQueue.main.async(execute: {
            self.tableView.reloadData()
        })
    }
    
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "myRankingGameDetail" {
            if let indexPath = tableView.indexPathForSelectedRow {
                let controller = segue.destination as! GameViewController
                controller.game = rankings[indexPath.row].game.fragments.gameBasic
                
            }
        }
    }
    
}


