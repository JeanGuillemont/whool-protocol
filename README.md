**# Whool

### Reference
This is a fork of the [slugs-protocol](https://github.com/bernatfp/slugs-protocol) of bernatfp

### Summary
The whool protocol is the onchain url shortener with NFT art on top. It aims to make short url rewarding for their creator, funnier and safer for the visitors by integrating a splash screen before link redirection.

### Description
The whool protocol is an onchain and NFT powered url shortener allowing the creation and the management of whools. A whool is a string alias NFT mapping to an url selected by its owner. The protocol can be integrated in any frontend supporting the registration, management and/or resolution of whool requests for redirection. However, it's first use is through the [whool_application](https://whool.art/) reprensenting the main use case (at the time of writing) of the protocol. Feel free to innovate on it.

The protocol and its app aims to improve the accessibility of customized short urls and improve the visibility of artist by randomly promoting newly minted NFTs on platforms. In return, the protocol owner or the whool owner get referral fee on mints made from the link splash screen.

Any individual or project participating the growth of the protocol either by spreading the word or by creating an application where users create whool will earn 30% referral fees on any custom whool minted.

### Genesis

### Whools ?

Whools are ERC721 NFT granting the owner to set the url corresponding to it. A whool can be :
- Random, in this case it will be a random string and will be free to mint (gas fee still needed). A random whool allow the owner to be referrer in 70% of case.
- Custom, in this case creator can choose the string used (if not already existing) and will require a static 0.001eth fee to be minted. A custom whool allow the owner to be referrer in 90% of case.

They are :
- Transferrable
- Perpetual
- Generative

### License

MIT License.
**
