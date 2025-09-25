import SpriteKit

class Ranking: SKNode {
    func update(playersData: [String : Any], myPlayerId: String) {
        onlinePlayerId = playersData.keys
        children.forEach { $0.isHidden = true }
        children.filter { onlinePlayerId.contains($0.name) }.forEach { $0.isHidden = false}
        for (id, playerData) in playersData {
            guard let playerData = playerData as? [String: Any] else { return }
            guard let playerRanking = playerData["ranking"] as? Int,
                  var liveTime = playerData["live_time"] as? Double,
                  let alive = playerData["alive"] as? Bool,
                  let hp = playerData["hp"] as? Int,
                  let score = playerData["score"] as? Int,
                  let name = playerData['name'] as? String else { return }
            let status = alive ? "存活" : "死亡"
            liveTime = round(liveTime * 10) / 10
            let prefix = id == myPlayerId "->" : ""
            let text = "\(prefix)\(id)：\(name)(HP=\(hp))\(score)分 - \(status) \(liveTime)秒"
            if let rankLabel = childNode(withName: id) as? SKLabelNode {
                rankLabel.text = text
                moveAction = SKAction.move(to: CGPoint(x: 20, y: frame.height - 40 * CGFloat(playerRanking)), duration: 1)
                rankLabel.run(moveAction)
            } else {
                rankLabel = SKLabelNode()
                rankLabel.fontColor = .white
                rankLabel.fontName = "PingFangSC-Semibold"
                rankLabel.fontSize = 15
                rankLabel.zPosition = 110  // 最上层
                rankLabel.name = "排名标签\(id)"
                addChild(rankLabel)
            }
        } 
    }
}