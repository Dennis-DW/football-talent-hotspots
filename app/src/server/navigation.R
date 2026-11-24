# Navigation links on the Overview page.
# Sourced inside server() with local = TRUE, so it shares input, output, session and the reactives.

# navigation links on the overview
observeEvent(input$go_map, nav_select("nav", "Map Explorer"))
observeEvent(input$go_why, nav_select("nav", "Why?"))
observeEvent(input$go_why2, nav_select("nav", "Why?"))
observeEvent(input$go_world, nav_select("nav", "World"))
observeEvent(input$go_map2, nav_select("nav", "Map Explorer"))
observeEvent(input$go_why3, nav_select("nav", "Why?"))
