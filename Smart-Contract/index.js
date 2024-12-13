const { ethers } = require("ethers");
const { generator_abi, generator,token_abi } = require("./ABI_");
const { default: axios } = require("axios");
const { SwapSide } = require("paraswap-core");
const Paraswap_price_API_URL = "https://apiV5.paraswap.io/prices";
const Paraswap_swap_API_URL = "https://apiV5.paraswap.io/transactions/137/";
const API_QUOTE_URL = 'https://polygon.api.0x.org/swap/v1/quote?';
const OPENOCEAN_URL = 'https://open-api-pro.openocean.finance/v3/137/swap_quote?';
const API_URL = "https://api.1inch.dev/swap/v6.0/137/swap";


require('dotenv').config();

let provider;



async function requestForSwap(tokenIn, tokenOut, amountIn, dex) {
    try {
        amountIn = ethers.parseUnits((amountIn).toString() ,(await getDecimal(tokenIn))).toString();
        let contract = await contractInstance(generator_abi, generator);
        let responce = await getSwapData([tokenIn, tokenOut], amountIn)
        let tx = await contract.requestFlashLoan([[tokenIn, tokenOut], "0x974613832F4aFf379856AFFAC37134fC103fEFDF",1000, amountIn,amountIn, responce.bestDex, responce.swapData], {gasPrice: ethers.parseUnits('37', 'gwei'), gasLimit: 10000000});
        let txHash = await provider.waitForTransaction(tx.hash);
        console.log({"Success..txHash":txHash.hash, "Status":txHash.status}); 
    } catch (error) {
        console.error(error.message)
    }
}


async function contractInstance(abi, address) {
    try {
        let contract = new ethers.Contract(address, abi, await getWalletSigner())
        return contract;
    } catch (error) {
        console.log(error);
    }
}


async function getWalletSigner() {
    try {
        provider = new ethers.JsonRpcProvider("Alchemy key");
        let wallet = new ethers.Wallet("Private key", provider);
        return wallet;
    } catch (error) {
        console.log(error);
    }
}

  
async function getSwapTransaction(sellToken, buyToken, amount) {
    let priceRoute;
    try {
      const config = {
          headers: {
              "Authorization": ""
          },
          params: {
            srcToken: sellToken,
            srcDecimals:await getDecimal(sellToken),
            destToken: buyToken,
            destDecimals: await getDecimal(buyToken),
            amount: amount,
            network: 137,
            side:"SELL",
            slippage:50
        }
      };
      let response = await axios.get(Paraswap_price_API_URL, config);
      priceRoute = (response.data.priceRoute);
      //console.log(priceRoute)
      try {
      let params = {
        srcToken: sellToken,
        destToken: buyToken,
        srcAmount: amount,
        destAmount: priceRoute.destAmount,
        priceRoute: priceRoute,
        userAddress: generator,
        receiver: generator,
        partner: "FABC",
        srcDecimals:await getDecimal(sellToken),
        destDecimals: await getDecimal(buyToken),
        ignoreChecks:true,
    }
        response = await axios.post(Paraswap_swap_API_URL, params);
        return({data:response.data.data, amount: priceRoute.destAmount})
      } catch (error) {
          console.log('Error making API request:', error);
      }
    } catch (error) {
      console.log(error);
    }
  }

async function getswapData(sellToken, buyToken, sellAmount) {
    const config = {
        headers: {
              "0x-api-key": ""
          },
        params: {
              "sellToken": sellToken,
              "buyToken": buyToken,
              "sellAmount": sellAmount,
              "enableSlippageProtection":true,
              "taker": generator,
              "slippagePercentage":1
          
            }
    };
    try {
        const response = await axios.get(API_QUOTE_URL, config);
        return ({data:response.data.data, amount: response.data.buyAmount})
    } catch (error) {
        console.error('Error making API request:', error);
    }
}


async function getDecimal(token) {
    let contract = await contractInstance(token_abi, token);
    return parseInt(await contract.decimals());
}

async function getSymbol(token) {
    let contract = await contractInstance(token_abi, token);
    console.log(await contract.symbol())
    return (await contract.symbol()).toString();
}

async function getOpenoceanSwapData(sellToken, buyToken, sellAmount) {
    const config = {
        headers: {
            "apikey": "",
        },
        params: {
              "inTokenAddress": sellToken,
              "outTokenAddress": buyToken,
              "amount": sellAmount,
              "slippage": 10,
              "gasPrice": 3,
              "account" : generator

            }
    };
    try {
        let response = await axios.get(OPENOCEAN_URL, config);
        return ({data:response.data.data.data, amount: response.data.data.outAmount})
    } catch (error) {
        console.error('Error making API request:', error);
    }
}

async function getSwapInchTransaction(sellToken, buyToken, amount) {
    try {
      const config = {
          headers: {
              "Authorization": ""
          },
          params: {
                src: sellToken,
                dst: buyToken,
                amount: amount,
                slippage: 1,
                from: generator,
                disableEstimate: true,
           }
      };
      try {
          const response = await axios.get(API_URL, config);
          return ({data:response.data.tx.data, amount: response.data.dstAmount})

      } catch (error) {
          console.error('Error making API request:', error);
      }
    } catch (error) {
      console.error(error);
      throw new Error(error);
    }
  } 

  async function getSwapData(tokens, amountIn) {
    let dex = [];
    let bestPrice = 0;
    let bestdex = 0;
    let calldata = [];
    let responce;
    let data = 0;
    for (let index = 0; index < tokens.length; index++) {
        if(index == 0) {
            responce = await getswapData(tokens[index], tokens[index + 1], amountIn);
            if(responce.amount > bestPrice) {
                data = responce.data;
                bestPrice = responce.amount;
                bestdex = 0;
            }
            // responce = await getOpenoceanSwapData(tokens[index], tokens[index + 1], amountIn/10**await getDecimal(tokens[index]));
            // if(responce.amount > bestPrice) {
            //     data = responce.data;
            //     bestPrice = responce.amount;
            //     bestdex = 2;
            // }
            responce = await getSwapInchTransaction(tokens[index], tokens[index + 1], amountIn);
            if(responce.amount > bestPrice) {
                data = responce.data;
                bestPrice = responce.amount;
                bestdex = 1;
            }
            // responce = await getSwapTransaction(tokens[index], tokens[index + 1], amountIn);
            // if(responce.amount > bestPrice) {
            //     data = responce.data;
            //     bestPrice = responce.amount;
            //     bestdex = 3;
            // }
            amountIn = bestPrice;
            bestPrice = 0;
            dex.push(bestdex)
            calldata.push(data)
            console.log({sell: amountIn, bestdex: dex});
        }
        if(index == 1) {
            responce = await getswapData(tokens[index], tokens[index - 1], amountIn);
            if(responce.amount > bestPrice) {
                data = responce.data;
                bestPrice = responce.amount;
                bestdex = 0;
            }
            // responce = await getOpenoceanSwapData(tokens[index], tokens[index - 1], amountIn/10**await getDecimal(tokens[index]));
            // if(responce.amount > bestPrice) {
            //     data = responce.data;
            //     bestPrice = responce.amount;
            //     bestdex = 2;
            // }
            responce = await getSwapInchTransaction(tokens[index], tokens[index - 1], amountIn);
            if(responce.amount > bestPrice) {
                data = responce.data;
                bestPrice = responce.amount;
                bestdex = 1;
            }
            // responce = await getSwapTransaction(tokens[index], tokens[index-1], amountIn);
            // if(responce.amount > bestPrice) {
            //     data = responce.data;
            //     bestPrice = responce.amount;
            //     bestdex = 3;
            // }
            dex.push(bestdex);
            calldata.push(data)
            console.log({buy: bestPrice, bestdex: dex});
        }
    }

    return ({bestDex: dex, swapData: calldata})

  }

  requestForSwap("0xc2132D05D31c914a87C6611C10748AEb04B58e8F", "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270",10);