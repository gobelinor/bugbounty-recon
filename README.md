# bugbounty-recon

## TODO : 
- Dockerisation pour eviter les installations des outils à chaque déploiement
- website-recon.sh
- appeler website-recon.sh dans recon-domain.sh

## Install container and launch script :

#### Build container
```bash
docker build -t recont-tool .
```

#### Run on domain
```bash
docker run --rm -v $(pwd)/results:/recon recon-tool example.com
```
