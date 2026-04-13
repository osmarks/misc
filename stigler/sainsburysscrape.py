from curl_cffi import AsyncSession
from bs4 import BeautifulSoup
import asyncio
import re
import base64
from urllib.parse import unquote
import collections
import json

headers = dict([ y.split(": ", 1) for y in r"""Host: www.sainsburys.co.uk
User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:149.0) Gecko/20100101 Firefox/149.0
Accept: application/json
Accept-Language: en-GB,en;q=0.9
Accept-Encoding: gzip, deflate, br, zstd
Referer: https://www.sainsburys.co.uk/gol-ui/features/new-in-season
authorization: Bearer eyJhbGciOiJSUzI1NiIsImtpZCI6InB1YmxpYzowOTk5OGU0Ny02M2U2LTRkZTktOTEzYS03MjJjMjVkOGMxZjMifQ.eyJhdWQiOlsiZ29sLnNhaW5zYnVyeXMuY28udWsiLCJhY2NvdW50LnNhaW5zYnVyeXMuY28udWsiXSwiY2xpZW50X2lkIjoiZ29sIiwiZXhwIjoxNzUwMDIxNjY2LCJleHQiOnt9LCJpYXQiOjE3NTAwMTgwNjUsImlzcyI6Imh0dHBzOi8vYWNjb3VudC5zYWluc2J1cnlzLmNvLnVrLyIsImp0aSI6ImI0NWM0MGNhLWU4N2YtNDA3MS1iMjg3LTY3MjdmMzhhYWM1MyIsIm5iZiI6MTc1MDAxODA2NSwic2NwIjpbIm9wZW5pZCIsIm9mZmxpbmUiLCJnb2wtc2Vzc2lvbiJdLCJzdWIiOiJlYjIxZmYxYi1mNDBmLTQxNzctODY3YS00NmEzMjI2MDlhMDIifQ.dIlc3VOKXRzuON4jvwBmNT-tB4pZJSicyA_Wqy181YiajA3X9aym6MbN1LlE5AgOHfH5rvICHh6a8P5vyZOHoPrNqwV05qm2OfQWKu062p0_NaVKtWDIUZvG44rmbMPPhuzGA4sbpmhpq15t1QjcpOoYpHeCVA1Xt04q5ALxCT2xRLePG_zxyH4ZbTzclEzjKJezX5nSi_F9_KSxYBgAgrFpouGITrXjBihrnm2B_3dnUoWcw1yQHHai_nxHBec4mRdpLn1x1h4vWzhAiGW2yGRa7v7myd9dpVqAPj8AZWDFiU4EJeGuPYnYo_4hPg1TbZn1C5I005NYO5G4o5wxo6AeoQaRARF0fW7GQjmAxiVNWcbv9-hoI--Ev_W_CiqyXXrHsZKjqWu_9UYQw2NaNH-xsajc3Yr2KmDlppCzRyO-gAd2c6sY36DtKn0NxepjJ1OAFzuCS2XJYepAEZBNmW3vkE1gZ7hNtPkm6UMWG54xI5SHA9ShXwVL-7LFNMeKbbyrOl_R1yM7FE72O_5EnGgbQoKfUIRXyTc6sRVyE0N5nJcYJIU0tFtZKQqXHd_v6g0mK53p8O7VE3d4aKGLRTS2On4DwFL_bCS-VIFbK3GoHIhbuuLAYLQ0NomRlA-AZtsgRP9VvCfcvVGnVoRbO9EvlpEtAskCG5l6VbmgWP4
content-type: application/json
enabled-feature-flags: add_to_favourites,use_food_basket_service,use_food_basket_service_v3,use_food_basket_service_v4,ads_conditionals,findability_v5,show_static_cnc_messaging,fetch_future_slot_weeks,click_and_collect_promo_banner,cookie_law_link,citrus_banners,citrus_favourites_trio_banners,offers_strategic_magnolia,special_logo,custom_product_messaging,promotional_link,promotional_link2,promotion_mechanics_page,findability_search,findability_autosuggest,findability_orchestrator,fto_header_flag,recurring_slot_skip_opt_out,first_favourite_oauth_entry_point,seasonal_favourites,cnc_start_amend_order_modal,favourites_product_cta_alt,get_favourites_from_v2,krang_alternatives,offers_config,alternatives_modal,relevancy_rank,changes_to_trolley,nectar_destination_page,unit_price_legislation,meal_deal_live,browse_pills_nav_type,use_cached_findability_results,event_zone_list,cms_carousel_zone_list,show_ynp_change_slot_banner,recipe_scrapbooks_enabled,event_carousel_skus,split_savings,trolley_nectar_card,favourites_magnolia,homepage,taggstar,meal_deal_cms_template_ids,pdp_accordions,pdp_occasions_pills,pdp_meta_desc_template,grouped_meal_deals,pci_phase_2,meal_deal_builder_nectar_widget,occasions_navigation,slots_event_banner_config,sales_window,resting_search,brands_background,brands_background_config,taggstar_config,all_ad_components_enabled,left_align_header,golui_my_addresses,new_global_header,new_filter_pages,spoonguru_disclaimers,recipe_reviews_enabled,sponsored_drawer,frequently_bought_together,show_ynp_opt_in_ui_elements,show_ynp_add_to_basket_toast,show_ynp_card,similar_products_drawer,fetch_ynp_opt_ins,resting_search_v2,bop_enabled,identity_transfer,prop_bar,favourites_boards,slot_confirmation_board,mobile_nav_2,highlight_seasonal_nav_item,should_not_scroll_into_view_fbt,show_popular_categories,compact_reviews,track_remove_scroll_experiment,favourites_grouped_by_top_category,track_boards_experiment,ynpoptin_national_launch,favourites_link_on_global_header,hey_sainsburys,heys_resting_state,krang_newness,show_tpr_straplines,track_compact_tile_experiment,track_pdp_occasions_pills_experiment,use_compact_tile_boards,use_compact_tile_previous_orders,use_compact_tile,use_op_orchestrator_sde,occasions_closure_end_date_2025,favourites_view_all_AB_test,retry_your_payments,offers_revamp_2025_rollout,favourites_slot_your_usuals_tracking,product_bundles,fable_search_bar,hard_sku_replacement,occasions_available_from,track_occasions_available_from,continue_shopping_link,fto_first_available_slot,drip_pricing_phase_2_homepage,qualifying_basket_amount,offers_krang_recommendations_placement_ab_test,app_banner,bigger_images,call_bcs,catchweight_dropdown,citrus_preview_new,citrus_search_trio_banners,citrus_xsell,compare_seasonal_favourites,constant_commerce_v2,ctt_ynp_products,desktop_interstitial_variant,disable_product_cache_validation,event_dates,favourites_pill_nav,favourites_whole_service,favourites_your_usuals_tracking,fbt_on_search,fbt_on_search_tracking,ff_abc_test_display,first_favourites_static,foodmaestro_modal,hfss_restricted,interstitial_variant,kg_price_label,krang_recommendations,lp_ab_test_display,lp_interstitial_grid_config,meal_planner,meganav,mobile_interstitial_variant,my_nectar_migration,nectar_card_associated,nectar_prices,new_favourites_filter,new_favourites_service,new_filters,ni_brexit_banner,occasions,offers_mechanics_carousel,optimised_product_tile,promo_lister_page,recipes_ingredients_modal,review_syndication,rokt,sale_january,search_cms,show_hd_xmas_slots_banner,similar_products,slot_v2,sponsored_featured_tiles,xmas_dummy_skus,your_nectar_prices
traceparent: 00-5db91757c9174e8fa026af234a6e40e0-75afa803ef67f9c0-01
tracestate: 2092320@nr=0-1-1782819-181742266-75afa803ef67f9c0----1776013538777
wcauthtoken:
DNT: 1
Connection: keep-alive
Cookie: Apache=10.8.240.13.1663366451969838; JSESSIONID=0000ZfrS1stHepolhgHLsaiF56L:1e2e0ij35; REFERRER=https%3A%2F%2Fduckduckgo.com%2F; SESSION_COOKIEACCEPT=true; WC_SESSION_ESTABLISHED=true; WC_ACTIVEPOINTER=44%2C10151; AWSELBCORS=25AD1B631266486EDFA612488DCD352CF0D47ECF032AF6F0D069907C6E2C2B46097B67EEDE8F1C9CDECEA01F0FFD5FBE13E2736D586864440C3ABA4A60A307AE6095377DF7; last_button_track=false; search_redirect_flag=0; topnav_click=false; espot_click=false; prizeDrawPopUp_customer1In20Chance=false; akavpau_vpc_gol_default=1776013838~id=ee6b4935ed6bc3b25825e6fa87d24851; Bc=d:0*0.1_p:0*0.005_r:null*null; WC_PERSISTENT=K3x3qhivhjOqWD2ErlMoOkWiogA%3D%0A%3B2025-06-15+21%3A07%3A47.289_1749899626228-687_10151; akavpau_vpc_gol_bookslot=1750018381~id=c045edd157b2aad7b973182a4872351f; _cls_s=7218f479-1c67-41b0-9aaa-1e2890162afa:0; akaas_gol_random=22; bm_ss=ab8e18ef4e; _abck=49A40D15E40E238E458E64C90320EE84~0~YAAQSw8DF3amXFGdAQAA+/Cngg8X/gWJ2WpOScuR/RwPhH1D3LkQiUUELAEBbNirwEqKgqpf7w04L3xTiA3QZC+TtOPeX7+hX90V2GtAC8pS1hMoc323X/AByvPOINE07OBAW04OfLsAOXHA8UV26+/pY0B1PaAUutQJ1OiW/OWTlHivxi/v0iYOv5zSf+lkNWHJN1JHH9lGvbKCXztqcJHtCzg9YBTPtfZWMhv7GB6hZByKooS9+bW5gRVjEeLS+z9Tapb97nYtpXl3oPYWJ2CAiBlJ67R45BJ5Td5KmvWU+s9uUpt9i+RucHJ75MXfzhcoygyHsDZb0gSOQayubtcXfeXM0jNbOks9Ya4Mt5fk/+YiH5isNZbSZikB7b0w83oAd8awoNt5DZJCN9bzoGCSrzxQxVTE5YfyQ1oH4ku3+OJXZrwWSc46e3ISHQrKUl0Xj/8zxqvfXwnMwsH8i8b9hUXfoytPMyxCHFOvBpKif+N1J8wObvVcUoj7EUriQgGZ+qBdbSNOA59HynbeuOgtQtpK9fij4fq2T3AS6ztHvLuhC2FPfxDBdLHuRz6PMHUb124w6X+kVPQ6UYVJPMGQZi0uBdU3Pr5K1r2jXfT4+7GVLMEHgGGDxHtchxdbU2l7/KMgQBXGuY1a4F4GoJJOF3tWY/zPvHYSoIthFz5w2jHmy2GplfJm4wmZE1Z+wzlI9feYYYsoDVtVCcopu/AjyJ0L+WvMHQySX81ye7+W/xkGNklaVZBacl2dlARZir8SuXU9MXQqz2WpkocxjHjFn6mgrzn69X2+6oVpcYs19nCN4LIIleebPb9u0cNryPfmsSrZeMBhK3v4vOUe3wF31gsut9xwWTAkoMvNRJ3LeHo9t+PTK8o9WD1OOpe6iLQZlnQPDJ75ZfrP+0JTbj0jNAnO0WmnjRARlYAe1+A/3NlhjQmTZ86A7bHHawc4o2RPgL9sMreQSIwUb4sAcC6rg9rn1PjHcE1cTw==~-1~-1~-1~AAQAAAAF%2f%2f%2f%2f%2f6J%2fNJlDLE7GlwSqnSJY2+h4c0qJDzXzw49GzOLkiJA0ZzRoeaC28YjUW%2fgLDIVCJvofXQOBVpNRXyyP57QpkhV1gKg29WSrriox~-1; bm_s=YAAQSw8DF1CmXFGdAQAAZfCnggWLJxE/c7jaFU7Syb45klLXH0yJLL/y8cdRN7iXsuLcnQrKvxNxfZ50iWh29AJtlqlbNEnKhaUws1sa6Tar4g8Spz5Ae6WlnXgq7z4KE1kisr4YQiv0eamAg2nnGC28NccJse/uP96xy44xBMk1Evzb0gUIc6HQL1FqxznCgQi9TmOVkYuPeB3VS8KKiDNnAeLiKrxyG3fxTXjl0Xi9SfN7ZPiNfBVy2vvqBiqpK2SVlYs9mHmdLBMP+8DHTnU6ODshMOXuvx76YPz1bPvkRyeAMJ6IxDz4ygP7yXO46VnQTa83vNIccEsmYcA/G9UuS5rgF7p2dchY+wQGvFMv9cePpNGYu4XIHZUmJf6SdTqsG/tnTT8ApkDWVYeJDVtg5CgTkv02TtFg6hfbf90ocQYLsxZna8tCagHsobexzEp/u9tQFcrSappO7SK0yC5x13v5/yFK0FtPDEdesPJLGB3OCF0b7DQrBRAhvTmtCTDYPoMlihyn6J5ooHgawCS7saSxTLlU1+sjp7fRJbmRkmzeXRloN3Cifx0wD2NadbArirHkVO1m2ct0AesizXCDBsnbrqeXdXGeGSJgtBZC0q7rhWORp5gfSK0qAo82UdW+yzC+RI5J3tCxZAgTduapYTOlNVTiTC+B4sG0/UVwl3H5v16/PGSAwbBmIpcblnCRrROwDONV+wnz+TcqOQsyxyRvr05QQgungclBuTLH3WG1YS4G7waVICoaDkcJY5rxXBY81vPX6hQ+oJVp1CoAmRil2gpVwVKMrzp+t2oehNTjN4t9cR5TqmKkMyjoASG9/Q31lcuZmV3ONjlorYioX9uEoJ0mOUovTdcgJMpSD47AtBVT9ZcWcW8/IEKKu8MAwu54FoE9aC7LyL2kSqbv; bm_so=54484B0196D716EF72CD8FA4EB13859B21B7F8A85C65FA1FC4EF3F4A5F3FF6DD~YAAQSw8DF1GmXFGdAQAAZfCnggcQuNpBiQ0VAdXFSrxMrn7SjgjdjC0RV6wEYeNC1iajPHEu5249fmuC/OIdeKzN6Pg0pWO0olOXgThMmxluyBO4clt8e7kwiHbJg45aahz6iDf+p3s7WS4bnzDvhdTBYLM1sclcJLULrC4YY+KGDeNvOokga+WCea7OVWRxX2rGrkhdK36opRFPjgpmb6MwV6CwQtNmkTzZK7tD4nVTbd4gwh6Tc26GZYzR+nlTL8UiDc89xhQQceryV3oZDcWIsZLX0a4GadEAEA4WUloOeGHw31zK1cWrVx3wtBNJvZ4Ma1I01XUlgTv3IvnQBU0tcuRoLGvKRE2uqtGIwlQHcMj1iJ7vGZN7Q/geupXaXCK02DuXO72xmGgoIHYEVfR9PLB1MbIUub4Q+Z/TksAdXq0xmdNomauedHbMhF4g2K8VFewuBFat0l02HsxpUJHCZW6XuSSaXygdnhN3; bm_sz=00BEF0DA76852BE626CC7B06D5353ABD~YAAQSw8DF1OmXFGdAQAAZfCngh8c8TFOHBvhRpWZdd3wLV8gahDfSvx3vPhEckUiwD996EMewVnScAkZXjQQzgVY/yX6+AviLZSfhCPrcAhH3dKFxLPvkHdqUOQgcf5eV8D3JrJ0MbEXg0ZDq8vw/jq0m0aTmrltk4xpXGMWQXN7wM9gqDN/wlx2MlffxLCQbXKjt5Mav7GOYEocqGLA7w+WaG8wgFNvFAw1gLa8aFNMWTieoU7XX75MOQEwB3Yu3UYnnVOpR3wW1KoCL3XycuAClPVt1R6hlRDjEr7Wbmer4YgmZ1ismILxSiXWyzOgh998dWgwRVoTj21DdMbLxH2zCwJwUU90C9xVqZcFEc/HG0XO5J9bM8AuqMBi9APh5+q3tmeNgVktBSdk+P40c+ipeOvlzWIxbEF4ONk5YeJPh8xQOwmDjNd7cr+qV3przfJj~4277318~4473653; ak_bmsc=59B34C94CE5F1E8B95A097825F642884~000000000000000000000000000000~YAAQSw8DF9H0W1GdAQAA+2yjgh94LPS+EYFLRIw8M/vngPtTQpMQUx+bZwJ1GB3ly15tlAwn7AoZNA7JtPrx7UpYGFvDBYuZ7Y/Pd55gryGab7k0m3b8m08QGNr/nLJxgpI62viMF7RTK1LsBZLFr73CttayjgG66knY4RbfaM0PS5L0BHXflouszOefIibqETtj23R0yCA1LQpYbMhWdB9e1Rhdbusn5Uiwa0acHyOzLeyqpgRyDweK4s8zsbGd9WdGsRagCBdjy4PitRKPKSOlKf4SoRNIncWBu+woP74KqFGqR0KPAh2kHZyv4V/h8iOqA2li3JzVrPd1NpYSGB5+DH//0iKhUTPWvz2Sfk4EL4sDf0qwaKG2cO5cg5SD6ZqOwIpqBYFwuWrXB6zch8co1mk5twff; utag_main=v_id:019d82a36d81001f05c5435bcba705046001d00901788$_sn:1$_ss:0$_st:1776015337669$ses_id:1776013241729%3Bexp-session$_pn:3%3Bexp-session$previousPageName:web%3Agroceries%3Afeatures%3Anew%20in%20season%3Bexp-session$previousPageType:%3Bexp-session$previousSiteSection:features%3Bexp-session$previousPagePath:%2Fgol-ui%2Ffeatures%2Fnew-in-season%3Bexp-session$dc_visit:1$dc_event:26%3Bexp-session$megaNavDestPageName:web%3Agroceries%3Afeatures%3Anew%20in%20season%3Bexp-session; bm_lso=54484B0196D716EF72CD8FA4EB13859B21B7F8A85C65FA1FC4EF3F4A5F3FF6DD~YAAQSw8DF1GmXFGdAQAAZfCnggcQuNpBiQ0VAdXFSrxMrn7SjgjdjC0RV6wEYeNC1iajPHEu5249fmuC/OIdeKzN6Pg0pWO0olOXgThMmxluyBO4clt8e7kwiHbJg45aahz6iDf+p3s7WS4bnzDvhdTBYLM1sclcJLULrC4YY+KGDeNvOokga+WCea7OVWRxX2rGrkhdK36opRFPjgpmb6MwV6CwQtNmkTzZK7tD4nVTbd4gwh6Tc26GZYzR+nlTL8UiDc89xhQQceryV3oZDcWIsZLX0a4GadEAEA4WUloOeGHw31zK1cWrVx3wtBNJvZ4Ma1I01XUlgTv3IvnQBU0tcuRoLGvKRE2uqtGIwlQHcMj1iJ7vGZN7Q/geupXaXCK02DuXO72xmGgoIHYEVfR9PLB1MbIUub4Q+Z/TksAdXq0xmdNomauedHbMhF4g2K8VFewuBFat0l02HsxpUJHCZW6XuSSaXygdnhN3~1776013538363; RT="z=1&dm=www.sainsburys.co.uk&si=9f2acc53-ae82-4012-a975-63939f10aeff&ss=mnw0ffb6&sl=3&tt=4u2&bcn=%2F%2F684dd311.akstat.io%2F"; OptanonConsent=isGpcEnabled=1&datestamp=Sun+Apr+12+2026+18%3A05%3A38+GMT%2B0100+(British+Summer+Time)&version=202508.2.0&browserGpcFlag=1&isIABGlobal=false&hosts=&genVendors=V12%3A0%2CV13%3A0%2C&consentId=eebf9b0f-46b6-4f81-96bf-de72b45ae81b&interactionCount=1&isAnonUser=1&landingPath=NotLandingPage&groups=1%3A1%2C2%3A1%2C3%3A1%2C4%3A1%2CV2STACK42%3A1&intType=1&geolocation=GB%3BENG&AwaitingReconsent=false; AWSALB=WN8WPqr+aRhprRfMgIt65myAr3UEIkWnRAYKP2rD0AXsJlbaYHrPbf379hW3BJJes6bi7NCI1syyQhH60ynr2OZGR/UWM52C34jrCO77IBJ/Qn5kzJiTjQ7aNmu3; AWSALBCORS=WN8WPqr+aRhprRfMgIt65myAr3UEIkWnRAYKP2rD0AXsJlbaYHrPbf379hW3BJJes6bi7NCI1syyQhH60ynr2OZGR/UWM52C34jrCO77IBJ/Qn5kzJiTjQ7aNmu3; bm_sv=72193FF6414238C93C863FC89FC92ED8~YAAQSw8DFxOnXFGdAQAAdfWngh+DxASr3+GOfxQFOk7/wE6RWE+xaoNgQ6+o4hAllku9opxoa6myYe2Roj6qh3vlnM74VUDI78+e972VFOPc7bKULX1yGlkVEGAo2VIgIb5ig0/BdXnyafNaB4z0U6baKly9rKFPhlX1xy4oDYsN7n4hzWDTuivgqv7yQD/YxncIw5dc/HItjn8FWbMLmt8febZ2oi7HP7tkHIRPnDIhwhWjE4Ty5dhiZftbf6JdzjoiUmVniw==~1; OptanonAlertBoxClosed=2026-04-12T17:00:44.067Z; eupubconsent-v2=CQijDhgQijDhgAcABBENCaFsAP7AAAAAAChQF5wDgAFAAcABAAC0AGgAPQAmABtAEAAIQAfoBAwCOgLzAAAAIEgDgAcABAADQAJgAhAB-gLzHQBwAOAAgABoAEwAfoBHQF5koAYAHAAmALzKQBwAOAAgABoAEwAfoBHQF5gA.f9gAAAAAAAAA; GOLVI=9f67ebbb0d22472f914d8e613c3fbaa8; Gol_New_Groceries=groceriesweb; _cls_v=a022ae01-0f72-4d72-9a06-62d90bfb3907; _twpid=tw.1776013244711.822364549154851620; _scid=2fa9vOJ0DHNRWQXJ4I9DBcOLeTimdUYUq3dQgA; _fbp=fb.2.1776013244876.115293453187408394; akaas_gol_global=1783789538~rv=52~id=2184464a24897e20f8ece1d37fb9baed; _scid_r=2va9vOJ0DHNRWQXJ4I9DBcOLeTimdUYUq3dQgQ; _uetsid=27550d70369111f1b5c115defb076559; _uetvid=6a5b7600df1c11efbfa9439c5e5ce3e6
Sec-Fetch-Dest: empty
Sec-Fetch-Mode: cors
Sec-Fetch-Site: same-origin
Sec-GPC: 1
Priority: u=4
TE: trailers""".replace("wcauthtoken:", "wcauthtoken: ").split("\n") ])

mapping = {
    "100g": ("kg", 0.1),
    "100 g": ("kg", 0.1),
    "100ml": ("ltr", 0.1),
    "100 ml": ("ltr", 0.1)
}

def fix_commas(x):
    return re.sub(r"(\d+),(\d{1,2})", r"\1.\2", re.sub(r"(\d+),(\d{3})", r"\1\2", x))


def process_grocery(slug, x):
    price = x["unit_price"]
    name = x["name"]
    details = BeautifulSoup(base64.b64decode(x["details_html"]), features="lxml")
    for accr in details.find_all(id="accordion-content"): # ...
        h = accr.find("h3")
        if h.text == "Nutrition":
            table = accr.find("table")
            headers = [ g.text for g in table.find("thead").find_all("th") ]

            per_x_index = None
            per_x_value = None

            for i, label in enumerate(headers):
                for name, value in mapping.items():
                    if name in label.lower() and not "ref" in label.lower():
                        per_x_index = i
                        per_x_value = value
                if per_x_index:
                    break

            if not per_x_index:
                print("no match on", slug)
                return

            nutrition = {}

            for i, row in enumerate(table.find_all("tr")):
                if i == 0: continue
                cells = list(zip(headers, [ g.text for g in row.children if g.name in {"th", "td"} ]))
                if len(cells) < len(headers): continue

                label = cells[0][1]
                value = cells[per_x_index]

                if value[1] not in {"-", ""}:
                    nutrition[label] = value[1], per_x_value

            return slug, name, price, nutrition

async def main():
    async with AsyncSession(headers=headers) as sess:
        async def get_page(n):
            res = await sess.get(f"https://www.sainsburys.co.uk/groceries-api/gol-services/product/v1/product?filter[keyword]=&productsOnly=true&page_number={n}&page_size=20&sort_order=price")
            return { x["full_url"] for x in res.json()["products"] }

        async def get_grocery(i):
            slug = i.removeprefix("https://www.sainsburys.co.uk/gol-ui/product/")
            res = await sess.get(f"https://www.sainsburys.co.uk/groceries-api/gol-services/product/v1/product?filter[product_seo_url]=gb%2Fgroceries%2F{slug}&include[ASSOCIATIONS]=true")
            x = res.json()["products"][0]
            return x

        with open("sainsburys.jsonl", "w") as f:
            i = 1
            while True:
                print(i)
                nxt = await get_page(i)
                if not nxt: break
                groc = await asyncio.gather(*(get_grocery(x) for x in nxt))
                for g in groc:
                    json.dump(g, f, separators=(',', ':'))
                    f.write("\n")
                i += 1

#asyncio.run(main())

targets = (
    "energy",
    "fat",
    "saturate",
    "carbohydrate",
    "sugar",
    "protein",
    "salt",
    "fibre",
    "starch"
)

def process():
    with open("sainsburys.jsonl", "r") as f:
        with open("items.jsonl", "a") as h:
            for line in f:
                obj = json.loads(line.strip())
                res = process_grocery(obj["full_url"].removeprefix("https://www.sainsburys.co.uk/gol-ui/product/"), obj)
                if res:
                    slug, name, cost, nutrition = res
                    #if "biscuit" not in slug: continue
                    values = {}

                    print(slug, nutrition)

                    for target in targets:
                        for label, (value, value_scale) in nutrition.items():
                            label = label.lower()
                            if label and target.lower() in label:
                                value = fix_commas(value.split("/")[0].split("(")[0].strip())
                                if value.lower() == "trace": value = "0"
                                is_kj = "kj" in value.lower() or "kj" in label.split("/")[0].strip()
                                if target not in values:
                                    if is_kj:
                                        value = value.lower().removesuffix("kj").removeprefix("<").strip()
                                        value = float(value) / 4.2 # kcal
                                        value /= value_scale[-1] # per kg or litre or whatever
                                    elif value.endswith("%"):
                                        value = value.lower().removeprefix("less than").strip().removeprefix("<").removesuffix("%")
                                        value = float(value) / 100 * 1000
                                    else:
                                        value = value.replace(" ", "").removeprefix("<").removesuffix(")").removesuffix("*").removesuffix("g").removesuffix("kcal")
                                        value = float(value)
                                        value /= value_scale[-1]
                                    values[target] = value
                                    break

                    if cost["measure"] not in {"ltr", "kg"}:
                        continue
                    cost = cost["price"] / cost["measure_amount"]

                    json.dump({
                        "slug": "sainsburys/" + slug,
                        "nutrition": values,
                        "cost": cost,
                        "name": name
                    }, h)
                    h.write("\n")

process()
