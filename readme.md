My blog was created from the following instructions:

<https://melcher.dev/draft/2019-03-21-running-hugo-on-azure-for-2-a-month/>

Markdown Cheatsheet:

<https://github.com/adam-p/markdown-here/wiki/Markdown-Cheatsheet>

Hugo Theme is from:

<https://themes.gohugo.io/gohugo-theme-ananke/>

<https://github.com/budparr/gohugo-theme-ananke>


Creating an empty hugo site:
```docker
docker run --rm -e HUGO_WATCH=true --name "my-hugo" --publish-all --volume "$(pwd)/src:/src" --volume "$(pwd)/output:/output" -p 1313:1313 jojomi/hugo hugo new site .
```

Run the following command to execute Hugo blog site generation and run locally:

```docker
docker run --rm -e HUGO_THEME=gohugo-theme-ananke -e HUGO_WATCH=true -e HUGO_REFRESH_TIME=30 --name "my-hugo" --publish-all --volume "$(pwd)/src:/src" --volume "$(pwd)/output:/output" -p 1313:1313 jojomi/hugo
```

Creating new post
To create new post, run following command:
```docker
docker exec -it my-hugo hugo new post/tech-3.md
```

Running azure tools from bash command line under node:
```docker
docker run -it --rm --name node node bash

npm install -g yo generator-team

useradd -ms /bin/bash docker
su - docker

yo team:azure
```

Generate final docker release:
```docker
docker run --rm -e HUGO_THEME=gohugo-theme-ananke -e HUGO_BASEURL="https://www.mark-isaacs.com" --name "hugo-release" --publish-all --volume "$(pwd)/src:/src" --volume "$(pwd)/output2:/output" jojomi/hugo
```

How to update output folder to include drafts:

```docker
docker exec -it my-hugo sh

cd /
hugo --source="$(pwd)/src" --theme="$HUGO_THEME" --destination="$HUGO_DESTINATION" --baseURL="$HUGO_BASEURL" --cleanDestinationDir --buildDrafts
```


Important links:

https://simoncann.com/wotl/hugo-draft-future/
https://miketabor.com/how-to-host-a-static-website-using-aws-s3-and-cloudflare/
https://lustforge.com/2016/02/27/hosting-hugo-on-aws/
https://lustforge.com/2016/02/28/deploy-hugo-files-to-s3/


Compress images using: https://tinypng.com/
