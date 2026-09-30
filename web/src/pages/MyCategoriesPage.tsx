import { useEffect, useState } from 'react';
import * as myCategories from '../lib/myCategories';
import type { MyCategoryEntry } from '../lib/myCategories';
import { categoryStyle } from '../lib/categoryColor';

interface Props {
  platformName: (id: string) => string;
  onOpenCategory: (platform: string, area: { areaId: string; areaType?: string; typeName?: string; areaName?: string }) => void;
  onOpenCategoryIndex: () => void;
}

/**
 * 我的分类 (/my-categories): grid of locally saved categories across
 * platforms (localStorage via lib/myCategories). Click a tile to open its
 * category rooms; hover a tile to remove it.
 */
export default function MyCategoriesPage({ platformName, onOpenCategory, onOpenCategoryIndex }: Props) {
  const [entries, setEntries] = useState<MyCategoryEntry[]>(() => myCategories.listMyCategories());

  // Stay in sync with save/remove done on the category index page.
  useEffect(() => myCategories.subscribeMyCategories(() => setEntries(myCategories.listMyCategories())), []);

  return (
    <div className="discover">
      <h2 className="category-index-title">我的分类</h2>
      {entries.length === 0 && (
        <div className="banner">
          <span>还没有收藏的分类——去分类索引页点瓦片右上角的 ★ 收藏喜欢的分类吧。</span>
          <button type="button" className="btn-small" onClick={onOpenCategoryIndex}>
            去分类索引页
          </button>
        </div>
      )}
      <div className="category-tiles">
        {entries.map((entry) => {
          const style = categoryStyle(entry.areaName || entry.typeName || '');
          return (
            <div key={`${entry.platform}:${entry.areaId}`} className="my-category-cell">
              <button
                type="button"
                className="category-tile"
                onClick={() =>
                  onOpenCategory(entry.platform, {
                    areaId: entry.areaId,
                    areaType: entry.areaType,
                    typeName: entry.typeName,
                    areaName: entry.areaName,
                  })
                }
              >
                <span className="my-category-platform">{platformName(entry.platform)}</span>
                <span
                  className="category-tile-name"
                  style={style ? { background: style.background, color: style.foreground } : undefined}
                >
                  {entry.areaName || entry.typeName || entry.areaId}
                </span>
              </button>
              <button
                type="button"
                className="my-category-remove"
                title="移除"
                onClick={() => setEntries(myCategories.removeMyCategory(entry.platform, entry.areaId))}
              >
                ✕
              </button>
            </div>
          );
        })}
      </div>
    </div>
  );
}
