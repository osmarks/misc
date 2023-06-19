from bs4 import BeautifulSoup
import requests
import os
import os.path

people = {

}

for round_id in range(6, 13):
    print("round", round_id)
    m = BeautifulSoup(requests.get(f"https://cg.esolangs.gay/{round_id}/").text, features="lxml")
    for file_link in m.select("details > summary > a"):
        name = file_link.parent.parent.previous_sibling.previous_sibling.previous_sibling.previous_sibling
        if "impersonating" in name.text:
            name = name.previous_sibling.previous_sibling
        assert "written by" in name.text, f"oh no {name.text}"
        name = name.text.split("written by ")[-1]
        name = people.get(name, name).lower()
        href = file_link.attrs["href"]
        filename = str(round_id) + "-" + href.split(f"/{round_id}/")[-1]
        full_href = f"https://cg.esolangs.gay{href}"
        os.makedirs(os.path.join("people", name), exist_ok=True)
        with open(os.path.join("people", name, filename), "wb") as f:
            with requests.get(full_href, stream=True) as r:
                r.raise_for_status()
                for chunk in r.iter_content(chunk_size=(2<<18)):
                    f.write(chunk)