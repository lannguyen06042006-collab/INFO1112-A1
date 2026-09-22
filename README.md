---
editor_options: 
  markdown: 
    wrap: 72
---

# Project 1: Sales Data EDA + SQL Analysis

## Problem

Phân tích dữ liệu bán hàng để tìm insight về doanh thu, lợi nhuận, và
hành vi khách hàng theo Category/Region/thời gian.

## Data

-   Dataset: Superstore-style sales data (2003 dòng, 2023–2024)
-   Nguồn: [thay bằng link Kaggle thật nếu dùng data thật, vd. Kaggle
    "Superstore Sales"]
-   Cột chính: Order Date, Customer ID, Category, Region, Sales, Profit,
    Discount

## Approach

1.  Data cleaning: xử lý missing values (Discount), loại duplicate
2.  Feature engineering: Order Month, Profit Margin
3.  EDA: xu hướng doanh thu theo tháng, so sánh Category/Region, ảnh
    hưởng của Discount lên Profit Margin
4.  SQL analysis: top customer, revenue theo tháng, margin theo
    Category/Sub-Category

## Findings

-   Insight 1: Doanh thu giảm nhẹ từ 2015 (\~480k) xuống 2016 (\~460k),
    sau đó tăng mạnh liên tục qua 2017 (\~600k) và đạt đỉnh ở 2018
    (\~720k) — cho thấy đà tăng trưởng tích cực trong 2 năm gần nhất.
-   Insight 2: Sub-Category "Phones" và "Chairs" dẫn đầu doanh thu (xấp
    xỉ nhau, \~320k), trong khi "Fasteners" thấp nhất — công ty nên tập
    trung nguồn lực marketing/tồn kho vào 2 nhóm sản phẩm chủ lực này.
-   Insight 3: Region "West" và "East" đóng góp doanh thu cao nhất
    (\~700k và \~670k), gần gấp đôi Region "South" (\~390k) — có thể cân
    nhắc mở rộng chiến lược bán hàng ở South để thu hẹp khoảng cách.
-   Insight 4: Segment "Consumer" chiếm hơn 50% tổng doanh thu (\~1.15
    triệu), vượt xa Corporate (\~0.68 triệu) và Home Office (\~0.26
    triệu) — đây là nhóm khách hàng cốt lõi cần giữ chân.

## Tools

Python (Pandas, Matplotlib, Seaborn), SQLite/SQL

## What I'd improve

-   Thử với dataset thật lớn hơn (Kaggle)
-   Thêm thống kê kiểm định (A/B testing) ở phần tiếp theo — Tuần 3
-   Xây dashboard tương tác (Power BI/Streamlit)

## How to run

``` bash
pip install pandas matplotlib seaborn jupyter
jupyter notebook week1_eda_superstore.ipynb
```
