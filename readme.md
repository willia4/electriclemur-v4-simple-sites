# Simple Sites

This repo houses metadata for creating "simple sites" in the new v4 design. 

In general, a "simple site" is a site which simply serves files from the file system. 

These are defined in `sites.json`. `deploy.sh` will then create a container for each site and set appropriate traefik metadata to serve the site correctly. 

As a special case, `deploy_crowglass.sh` will create a special "redirection" container that simply redirects to a different site. It will also configure the traefik metadata.
