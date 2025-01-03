library(tidyverse)
library(extrafont)

# Read the data (user will need to run this with their data)
nuclear_data <- read.csv("data/comed_load_and_nuclear_2024.csv")

# Convert timestamps to datetime 
nuclear_data$interval_start_ct <- as.POSIXct(nuclear_data$interval_start_ct, format="%Y-%m-%d %H:%M:%S")

# Calculate nuclear to load ratio
df <- nuclear_data %>%
  mutate(nuclear_ratio = est_nuclear_generation_mwe / comed_load_mwe)

# Calculate percentage of time nuclear exceeded load
pct_nuclear_exceeded <- round(mean(df$nuclear_ratio >= 1, na.rm=TRUE) * 100)
cat(sprintf("Nuclear generation exceeded load %d%% of the time\n", pct_nuclear_exceeded))

# Count days where nuclear exceeded load at any point
days_with_nuclear_exceeding <- df %>%
  mutate(date = as.Date(interval_start_ct)) %>%
  group_by(date) %>%
  summarize(had_nuclear_exceed = any(nuclear_ratio >= 1, na.rm=TRUE)) %>%
  summarize(total_days = sum(had_nuclear_exceed)) %>%
  pull(total_days)
cat(sprintf("Nuclear generation exceeded load on %d days\n", days_with_nuclear_exceeding))

# Calculate total load in TWh
# Each 5-min MW value needs to be divided by 12 to get MWh (since 5 min is 1/12 of an hour)
# Then sum and divide by 1,000,000 to get TWh
total_load_twh <- sum(df$comed_load_mwe, na.rm=TRUE) / 12 / 1000000
cat(sprintf("Total load: %.2f TWh\n", total_load_twh))

# Calculate total nuclear generation in TWh
total_nuclear_twh <- sum(df$est_nuclear_generation_mwe, na.rm=TRUE) / 12 / 1000000
cat(sprintf("Total nuclear generation: %.2f TWh\n", total_nuclear_twh))

# Create the plot
nuclear_plot <- ggplot(nuclear_data) +
  # Add points and thin line for Load
  geom_point(aes(x=interval_start_ct, y=comed_load_mwe, color="ComEd Load"),
            alpha=0.07, size=0.3) +
  geom_line(aes(x=interval_start_ct, y=comed_load_mwe, color="ComEd Load"),
            linewidth=0.1) +
  # Add line for nuclear generation
  geom_line(aes(x=interval_start_ct, y=est_nuclear_generation_mwe, color="Estimated Nuclear Generation"),
            linewidth=0.5) +
  # Add point for the latest load value
  geom_point(data=nuclear_data %>% slice_tail(n=1), 
             aes(x=interval_start_ct, y=comed_load_mwe, color="ComEd Load"),
             size=2) +
  # Customize colors
  scale_color_manual(values=c("ComEd Load"="#FF9999", "Estimated Nuclear Generation"="#3366CC")) +
  # Labels
  labs(x="",
       y="Megawatts (MWe)",
       title="How did the Northern Illinois grid perform in 2024?",
       subtitle="ComEd Zone Load vs Estimated Nuclear Generation in megawatts, 5-minute intervals",
       color="",
       caption="Chart: Michael McLean @mclean.bsky.social
ComEd zone, PJM Interconnection. Load data: GridStatus.io, Nuclear generation estimated using EIA Form 860 seasonal capacity, and power from the daily NRC Power Reactor Status report.
Data retrieved Jan 3, 2025.") +
  # Axis formatting
  scale_y_continuous(breaks = scales::pretty_breaks(n = 10),
                    label=scales::comma,
                    limits = c(0, NA)) +
  # Customize x-axis to show months
  scale_x_datetime(date_breaks = "1 month", 
                  date_labels = "%b",
                  expand = c(0, 0),
                  limits = c(min(nuclear_data$interval_start_ct), 
                           as.POSIXct("2024-12-31 23:59:59")),
                  breaks = seq(as.POSIXct("2024-01-01"), as.POSIXct("2024-12-01"), by="month")) +
  # Add statistics annotation with background box
  annotate("label", x = min(nuclear_data$interval_start_ct), y = 800,
           hjust = 0, vjust = 0,
           label = sprintf("2024 Wrapped\n⚡ %.1f Terawatt Hours of electricity consumed\n☢️ %.1f Terawatt Hours of estimated nuclear generation\n🕒 Est. nuclear generation exceeded load %d%% of the time\n📅 Est. nuclear generation exceeded load for a period of time on %d days",
                         total_load_twh, total_nuclear_twh, pct_nuclear_exceeded, days_with_nuclear_exceeding),
           size = 3.15,
           fill = "white",
           label.padding = unit(0.5, "lines"),
           label.r = unit(0, "lines")) +
  # Theme customization
  theme_classic() +
  guides(col = guide_legend(label.position = "top", nrow=1, hjust=0)) +
  theme(
    plot.title = element_text(hjust = 0.01, face="bold", margin = margin(b = 5)),
    plot.subtitle = element_text(hjust = 0.01),
    axis.text.y = element_text(color="black"),
    axis.text.x = element_text(color="black"),
    plot.caption = element_text(color="#404040", hjust=0, size=6),
    panel.border = element_blank(),
    panel.grid.minor = element_blank(),
    legend.position = "top",
    legend.direction = "horizontal",
    legend.key.spacing.x = unit(0.2, "cm"),
    legend.key.size = unit(.01, "cm"),
    legend.box.margin = margin(l = -10, t = 10),
    legend.box.just = "left",
    plot.background = element_rect(fill = "#f9f9f9"),
    panel.background = element_rect(fill = "#f9f9f9"),
    legend.background = element_rect(fill = "#f9f9f9"),
    panel.grid.major.x = element_line(color = "#f0f0f0", linewidth = 0.3),
    panel.grid.major.y = element_line(color = "#f0f0f0", linewidth = 0.3),
    text = element_text(family = "Arial"),
    axis.line = element_line(color = "#404040"),
    axis.ticks = element_line(color = "#404040"),
    axis.title = element_text(color = "#404040"),
    axis.text = element_text(color = "#404040"),
    plot.margin = margin(t = 20, r = 25, b = 20, l = 20, unit = "pt")
  )

ggsave(plot=nuclear_plot, "nuclear_comparison.png", height=6, width=8)
