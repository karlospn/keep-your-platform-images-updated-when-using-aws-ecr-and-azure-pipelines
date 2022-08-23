namespace IntegrationTest.WebApi.DTO
{
    public class FooRsDto
    {
        public FooRsDto(string message)
        {
            Message = message;
        }

        public string Message { get; set; }
    }
}
