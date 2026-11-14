import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import "../theme.css";
import { Landing } from "./Landing.tsx";

// Links shared before the split pointed at "/#/coins" etc.; send them to the dashboard.
if (location.hash.startsWith("#/")) {
  location.replace("/app/" + location.hash);
} else {
  createRoot(document.getElementById("root")!).render(
    <StrictMode>
      <Landing />
    </StrictMode>,
  );
}
