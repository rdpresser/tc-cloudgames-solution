namespace TC.CloudGames.Functions.Messages;

public class UserPurchaseMessage
{
    public Guid UserId { get; set; }
    public string Email { get; set; }
    public string ProductName { get; set; }
    public decimal Value { get; set; }
}
