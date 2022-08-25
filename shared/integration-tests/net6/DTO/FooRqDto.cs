using System.ComponentModel.DataAnnotations;

namespace IntegrationTest.WebApi.DTO
{
    public class FooRqDto
    {
        public FooRqDto(string data)
        {
            Data = data;
        }

        [Required]
        public string Data { get; set; }
    }
}
