import { accountAvMiddleware } from "@avalsys/account-av-web";
import { createMiddleware, createStart } from "@tanstack/react-start";

const appleAppSiteAssociation = {
  applinks: {
    details: [
      {
        appIDs: ["935PM55U6R.com.avalsys.seriesav.dev", "935PM55U6R.com.avalsys.seriesav"],
        components: [
          {
            "/": "/i/r/*",
            comment: "Series AV private share invite links"
          }
        ]
      }
    ]
  }
};

const appleAppSiteAssociationMiddleware = createMiddleware().server(async ({ next, request }) => {
  const url = new URL(request.url);
  if (url.pathname !== "/.well-known/apple-app-site-association") {
    return next();
  }

  return Response.json(appleAppSiteAssociation, {
    headers: {
      "cache-control": "public, max-age=0, must-revalidate",
      "content-type": "application/json"
    }
  });
});

export const startInstance = createStart(() => ({
  requestMiddleware: [appleAppSiteAssociationMiddleware, accountAvMiddleware()]
}));
