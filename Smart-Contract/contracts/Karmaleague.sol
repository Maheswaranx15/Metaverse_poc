// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Karmaleague is Ownable {

    IERC20 public rewardToken;

    struct Post {
        uint256 postId;
        string content;
        address author;
        uint256 timestamp;
        uint256 likesCount;
        uint256 commentsCount;
    }

    struct Comment {
        uint256 commentId;
        uint256 postId;
        string content;
        address commenter;
        uint256 timestamp;
    }

    struct Like {
        uint256 likeId;
        uint256 postId;
        address liker;
        uint256 timestamp;
    }

    struct User {
        uint256 postsCount;
        uint256 commentsCount;
        uint256 likesCount;
        uint256 rewardPoints; 
        uint256 ethDeposited;
        uint256 tokensDeposited;
    }

    mapping(address => User) public users;
    mapping(uint256 => Post) public posts;
    mapping(uint256 => Comment) public comments;
    mapping(uint256 => Like) public likes;
    
    mapping(uint256 => mapping(address => bool)) public hasLikedPost;

    uint256 public postCounter;
    uint256 public commentCounter;
    uint256 public likeCounter;

    uint256 public postRewardPoints = 2; // 5 points per post
    uint256 public commentRewardPoints = 1; // 3 points per comment
    uint256 public likeRewardPoints = 1; // 1 point per like
    uint256 public tokenRewardRate = 1 * 10**18; // 1 token per 100 reward points

    uint256 public postDeposit = 5 * 10**18; // 5 tokens
    uint256 public ethDeposit = 0.001 ether; // 0.001 ETH
    uint256 public tokenDeposit = 5 * 10**18; // 5 tokens


    event PostCreated(address indexed user, uint256 postId, string content);
    event CommentCreated(address indexed user, uint256 postId, uint256 commentId, string content);
    event Liked(address indexed user, uint256 postId, uint256 likeId);
    event RewardsClaimed(address indexed user, uint256 tokensClaimed);
    event EthDeposited(address indexed user, uint256 amount);
    event TokensDeposited(address indexed user, uint256 amount);
    event RewardsConverted(address indexed user, uint256 rewardPoints);
    event TokensBurned(address indexed user, uint256 amount);
    event RewardPointsReduced(address indexed user, uint256 rewardPoints);
    event AdminWithdraw(address indexed user, uint256 amount);

    constructor(address _rewardTokenAddress) Ownable(msg.sender) {
        rewardToken = IERC20(_rewardTokenAddress);
    }

    function depositEth() external payable {
        require(msg.value == ethDeposit, "Incorrect ETH amount");
        users[msg.sender].ethDeposited += msg.value;
        emit EthDeposited(msg.sender, msg.value);
    }

    // User deposits tokens and immediately converts to reward points
    function depositTokens(uint256 amount) external {
        // require(amount == tokenDeposit, "Incorrect token amount");
        // require(rewardToken.balanceOf(msg.sender) >= amount, "Insufficient token balance");
        // require(rewardToken.allowance(msg.sender, address(this)) >= amount, "Allowance not set");
        // rewardToken.transferFrom(msg.sender, address(this), amount);
        users[msg.sender].tokensDeposited += amount;
        // Convert deposited tokens to reward points immediately
        uint256 rewardPointsToAdd = (amount / tokenDeposit) * 10; // 5 tokens = 10 reward points
        users[msg.sender].rewardPoints += rewardPointsToAdd;
        emit TokensDeposited(msg.sender, amount);
        emit RewardsConverted(msg.sender, rewardPointsToAdd);
    }

    function AdmincreatePost(address user, string memory content) external onlyOwner {
        // Owner covers the posting cost in tokens
        require(rewardToken.balanceOf(owner()) >= postDeposit, "Owner has insufficient tokens for posting");
        require(rewardToken.allowance(owner(), address(this)) >= postDeposit, "Owner has not approved enough tokens");

        // rewardToken.transferFrom(owner(), address(this), postDeposit);

        // postCounter++;
        // posts[postCounter] = Post(postCounter, content, user, block.timestamp, 0, 0);

        // users[user].postsCount++;

        // Deduct 5 reward points as a "borrowing loan" from the user
        if (users[user].rewardPoints >= 5) {
            users[user].rewardPoints -= 5;
        } else {
            users[user].rewardPoints = 0; // Prevent negative reward points
        }

        emit PostCreated(user, postCounter, content);
    }

    function createPost(string memory content) external {
        require(rewardToken.balanceOf(owner()) >= postDeposit, "Owner has insufficient tokens for posting");
        require(rewardToken.allowance(owner(), address(this)) >= postDeposit, "Owner has not approved enough tokens");

        rewardToken.transferFrom(owner(), address(this), postDeposit);

        postCounter++;
        posts[postCounter] = Post(postCounter, content, msg.sender, block.timestamp, 0, 0);
        
        users[msg.sender].postsCount++;
        users[msg.sender].rewardPoints += postRewardPoints; 

        emit PostCreated(msg.sender, postCounter, content);
    }

    function commentOnPost(uint256 postId, string memory content) external {
        require(posts[postId].postId != 0, "Post does not exist");

        commentCounter++;
        comments[commentCounter] = Comment(commentCounter, postId, content, msg.sender, block.timestamp);
        if(posts[postId].author != msg.sender){
            posts[postId].commentsCount++; 
            users[msg.sender].commentsCount++;
            users[msg.sender].rewardPoints += commentRewardPoints; 
        }
        
        emit CommentCreated(msg.sender, postId, commentCounter, content);
    }

    function adminCommentOnPost(address user, uint256 postId, string memory content) external onlyOwner {
        require(posts[postId].postId != 0, "Post does not exist");

        commentCounter++;
        comments[commentCounter] = Comment(commentCounter, postId, content, user, block.timestamp);
        posts[postId].commentsCount++; 
        users[user].commentsCount++;
        
        // Reward the post owner
        if (posts[postId].author != user) {
            users[posts[postId].author].rewardPoints += commentRewardPoints; 
        }

        emit CommentCreated(user, postId, commentCounter, content);
    }


    function likePost(uint256 postId) external {
        require(posts[postId].postId != 0, "Post does not exist");
        require(!hasLikedPost[postId][msg.sender], "User has already liked this post");

        // hasLikedPost[postId][msg.sender] = true;

        // likeCounter++;
        // likes[likeCounter] = Like(likeCounter, postId, msg.sender, block.timestamp);
        // if(posts[postId].author != msg.sender){
        //     posts[postId].likesCount++; 
        //     users[msg.sender].likesCount++;
        //     users[msg.sender].rewardPoints += likeRewardPoints; 
        // }
        
        emit Liked(msg.sender, postId, likeCounter);
    }

    function adminLikePost(address user, uint256 postId) external onlyOwner {
        require(posts[postId].postId != 0, "Post does not exist");

        hasLikedPost[postId][user] = true;

        likeCounter++;
        likes[likeCounter] = Like(likeCounter, postId, user, block.timestamp);
        
        // Reward the post owner
        if (posts[postId].author != user) {
            posts[postId].likesCount++; 
            users[posts[postId].author].rewardPoints += likeRewardPoints; 
        }

        emit Liked(user, postId, likeCounter);
    }


    function claimRewards() external {
        User storage user = users[msg.sender];
        uint256 rewardPoints = user.rewardPoints;

        require(rewardPoints > 0, "No reward points available");

        uint256 tokensToClaim = (rewardPoints * tokenRewardRate) / 100;

        require(rewardToken.balanceOf(address(this)) >= tokensToClaim, "Insufficient tokens in contract");

        user.rewardPoints = 0;

        rewardToken.transfer(msg.sender, tokensToClaim);

        emit RewardsClaimed(msg.sender, tokensToClaim);
    }

    function getPostDetails(uint256 postId) external view returns (
        string memory content, 
        address author, 
        uint256 timestamp, 
        uint256 likesCount, 
        uint256 commentsCount, 
        uint256 rewardPoints
    ) {
        require(posts[postId].postId != 0, "Post does not exist");

        Post memory post = posts[postId];
        User memory user = users[post.author];

        return (
            post.content, 
            post.author, 
            post.timestamp, 
            post.likesCount, 
            post.commentsCount, 
            user.rewardPoints
        );
    }

      function ownerBurnUserTokens(address user) external onlyOwner {
        // Reduce the user's reward points by 1, preventing underflow
        if (users[user].rewardPoints > 0) {
            users[user].rewardPoints -= 1;
        } else {
            users[user].rewardPoints = 0;
        }

        emit RewardPointsReduced(user, users[user].rewardPoints);
    }

    function adminWithdraw(address user, uint256 rewardPoints) external onlyOwner {
        User storage userData = users[user];

        require(rewardPoints > 0, "No reward points provided");
        require(userData.rewardPoints >= rewardPoints, "User does not have enough reward points");

        uint256 tokensToWithdraw = (rewardPoints * tokenRewardRate) / 1;

        require(rewardToken.balanceOf(address(this)) >= tokensToWithdraw, "Insufficient tokens in contract");

        // userData.rewardPoints -= rewardPoints;

        rewardToken.transfer(user, tokensToWithdraw);

        emit AdminWithdraw(user, tokensToWithdraw);
        emit RewardPointsReduced(user, userData.rewardPoints);
    }

    function setPostRewardPoints(uint256 newPoints) external onlyOwner {
        postRewardPoints = newPoints;
    }

    function setCommentRewardPoints(uint256 newPoints) external onlyOwner {
        commentRewardPoints = newPoints;
    }

    function setLikeRewardPoints(uint256 newPoints) external onlyOwner {
        likeRewardPoints = newPoints;
    }

    function setTokenRewardRate(uint256 newRate) external onlyOwner {
        tokenRewardRate = newRate;
    }

    function setRewardTokenAddress(address newTokenAddress) external onlyOwner {
        rewardToken = IERC20(newTokenAddress);
    }

    function setPostDeposit(uint256 newDeposit) external onlyOwner {
        postDeposit = newDeposit;
    }

    function getUserRewardPoints(address user) external view returns (uint256) {
        return users[user].rewardPoints;
    }
}
