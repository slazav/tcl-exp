Create a timeplot:

* `TimePlot <name> <window name> <options>` -- create a timeplot
* `<name> add_data <time> <data list>` -- add data
* `<name> add_comment <time> <text>` -- add comment

Timeplot options:

* `-n -ncols`  -- Number of columns. If add_data suppli longer or shorter list it will be trancated or padded with zeros. Default 1.
* `-a -names`  -- Column names (appear in legends). Default values "data-$n".
* `-t -titles` -- Column titles (appear on axes). By default equals to names.
* `-c -colors` -- Plot colors. By default a color loop {red green blue cyan magenta yellow
                  darkred darkgreen darkblue darkcyan darkmagenta darkyellow black ...} is used.
* `-h -hides`  -- A list of 1 or 0, shows if columns should be hidden, default 0.
* `-l -logs`   -- A list of 1 or 0, shows if columns should have a logariphmic scale, default 0.
* `-f -fmts`   -- list of formats, default is "%g"
* `-N -maxn`   -- Number of points to be kept in the plot history or 0 for infinite data storage.
                  History is cleaned when number of points exeeds 110% of <maxn>. Default is 0.
* `-T -maxt `  -- Time to be kept in the plot history or 0 for infinite data storage.
                  History is cleaned when total time span of the data exeeds 110% of <maxt>. Default is 0.
* `-X -plots_x`  -- List of X settings for plot variants. Contains data column names used for x axis. "time" means time axis.
* `-Y -plots_y`  -- List of Y settings for plot variants. Contains lists of column names used for y axis. Empty list means "All".
                    By default plots_x and plots_y are "{time}" and "{{}}", it means "All vs. Time" plot.
* `-Z -zstyles`  -- List of plot zoom styles ("x" or "xy"). In "xy" mode all data have same y axis and zoomed together by a mouse.
                    In "x" mode x axis can be zoomed by a mouse, all plots can be shifted and scaled separately in y direction.
                    Default is x for first time plot and xy for other plots.
* `-C -use_comm` -- Use comments (default 0).
