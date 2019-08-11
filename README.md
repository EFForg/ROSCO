# ROSCO (Read-Only Snipe CLI Operative)

ROSCO is an interactive, ruby-based CLI interface for querying against an instance of Snipe.

## Setup

1. `git clone $THIS_REPO`
2. `cd $THIS_REPO`
3. `mkdir secrets`
4. `vim secrets/api_key.txt`
5. Enter a Snipe API Key: https://snipe-it.readme.io/reference#generating-api-tokens
6. Be on the same network as the Snipe instance you're querying

## Usage

1. `docker-compose up -d --build`
2. `docker-compose exec app ./rosco`
3. Select `Exit` to exit the routine gracefully
4. `docker-compose down` to shut down the container

## Example Queries

ROSCO can retrieve things like:

* all linux users
* all mac uers
* users that have more than 1 laptop checked out
* the sale price of a given laptop if sold today
* all laptops that are still under warranty
* all laptops that are older than X years old
* more!
