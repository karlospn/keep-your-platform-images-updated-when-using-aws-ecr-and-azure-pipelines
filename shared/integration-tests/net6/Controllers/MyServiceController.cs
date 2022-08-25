using IntegrationTest.WebApi.DTO;
using Microsoft.AspNetCore.Mvc;

namespace IntegrationTest.WebApi.Controllers
{
    [ApiController]
    [Route("[controller]")]
    public class MyServiceController : ControllerBase
    {

        [HttpPost]
        public ActionResult<FooRsDto> Post(FooRqDto request)
        {
            return new FooRsDto(request.Data);
        }
    }
}